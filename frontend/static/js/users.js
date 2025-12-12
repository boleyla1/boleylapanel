// static/js/users.js

// ===== Configuration =====
const API_BASE_URL = 'http://localhost:8000/api/v1';

// ===== Helper Functions =====
function getAuthHeaders() {
    const token = localStorage.getItem('access_token');
    if (!token) {
        console.error('❌ No access token found');
        window.location.replace('login.html');
        return null;
    }
    return {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
    };
}

function checkAuth() {
    const token = localStorage.getItem('access_token');
    if (!token) {
        console.warn('⚠️ Not authenticated, redirecting to login...');
        window.location.replace('login.html');
        return false;
    }
    return true;
}

// ===== Format Functions =====
function formatBytes(bytes) {
    if (!bytes || bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return Math.round((bytes / Math.pow(k, i)) * 100) / 100 + ' ' + sizes[i];
}

function formatDate(dateString) {
    if (!dateString) return 'N/A';
    const date = new Date(dateString);
    if (isNaN(date.getTime())) return 'Invalid Date';
    return date.toLocaleDateString('en-US', { year: 'numeric', month: '2-digit', day: '2-digit' });
}

function getStatusBadge(user) {
    const now = new Date();
    const expiry = user.expire_date ? new Date(user.expire_date) : null;

    if (!user.is_active) {
        return '<span class="status-badge inactive">Inactive</span>';
    }

    if (expiry && expiry < now) {
        return '<span class="status-badge inactive">Expired</span>';
    }

    if (user.data_limit && user.used_traffic >= user.data_limit) {
        return '<span class="status-badge limited">Limited</span>';
    }

    return '<span class="status-badge active">Active</span>';
}

function getTrafficBar(user) {
    const used = user.used_traffic || 0;
    const total = user.data_limit || 0;

    if (total === 0) {
        return `
            <div style="display: flex; flex-direction: column; gap: 5px;">
                <small style="color: #6C757D;">${formatBytes(used)} / Unlimited</small>
                <div class="traffic-bar">
                    <div class="traffic-bar-fill" style="width: 0%;"></div>
                </div>
            </div>
        `;
    }

    const percentage = Math.min((used / total) * 100, 100);

    return `
        <div style="display: flex; flex-direction: column; gap: 5px;">
            <small style="color: #6C757D;">${formatBytes(used)} / ${formatBytes(total)}</small>
            <div class="traffic-bar">
                <div class="traffic-bar-fill" style="width: ${percentage}%;"></div>
            </div>
        </div>
    `;
}

// ===== Display Users in Table =====
function displayUsers(users) {
    const tbody = document.getElementById('usersTableBody');

    if (!users || users.length === 0) {
        tbody.innerHTML = `
            <tr>
                <td colspan="6" class="text-center" style="padding: 40px;">
                    <i class="bi bi-inbox" style="font-size: 48px; color: #CCC;"></i>
                    <p style="margin-top: 15px; color: #6C757D; font-size: 16px;">No users found</p>
                </td>
            </tr>
        `;
        return;
    }

    tbody.innerHTML = users.map(user => `
        <tr>
            <td><strong>${user.username || 'N/A'}</strong></td>
            <td>${getStatusBadge(user)}</td>
            <td>${user.protocol || 'VMess'}</td>
            <td>${getTrafficBar(user)}</td>
            <td>${formatDate(user.expire_date)}</td>
            <td>
                <div class="action-buttons">
                    <button class="btn-icon edit" onclick="editUser(${user.id})" title="Edit User">
                        <i class="bi bi-pencil"></i>
                    </button>
                    <button class="btn-icon delete" onclick="deleteUser(${user.id}, '${user.username}')" title="Delete User">
                        <i class="bi bi-trash"></i>
                    </button>
                </div>
            </td>
        </tr>
    `).join('');
}

// ===== Load Users from API =====
async function loadUsers() {
    if (!checkAuth()) return;

    console.log('📡 Loading users from API...');
    const tbody = document.getElementById('usersTableBody');

    tbody.innerHTML = `
        <tr>
            <td colspan="6" class="text-center" style="padding: 40px;">
                <div class="spinner-border text-primary" role="status">
                    <span class="visually-hidden">Loading...</span>
                </div>
                <p style="margin-top: 10px; color: #6C757D;">Loading users...</p>
            </td>
        </tr>
    `;

    try {
        const headers = getAuthHeaders();
        if (!headers) return;

        const response = await fetch(`${API_BASE_URL}/users/`, {
            method: 'GET',
            headers: headers
        });

        console.log('📡 API Response:', response.status, response.statusText);

        if (response.status === 401) {
            console.error('❌ Unauthorized - Token invalid or expired');
            localStorage.clear();
            window.location.replace('login.html');
            return;
        }

        if (response.status === 403) {
            tbody.innerHTML = `
                <tr>
                    <td colspan="6" class="text-center text-danger" style="padding: 40px;">
                        <i class="bi bi-exclamation-triangle-fill" style="font-size: 48px;"></i>
                        <p style="margin-top: 15px; font-size: 16px;">Access Denied: Admin permissions required</p>
                    </td>
                </tr>
            `;
            return;
        }

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }

        const users = await response.json();
        console.log('✅ Users loaded successfully:', users.length);

        displayUsers(users);

    } catch (error) {
        console.error('❌ Failed to load users:', error);
        tbody.innerHTML = `
            <tr>
                <td colspan="6" class="text-center text-danger" style="padding: 40px;">
                    <i class="bi bi-exclamation-circle-fill" style="font-size: 48px;"></i>
                    <p style="margin-top: 15px; font-size: 16px;">Error loading users: ${error.message}</p>
                    <button class="btn btn-primary mt-3" onclick="loadUsers()">
                        <i class="bi bi-arrow-clockwise"></i> Retry
                    </button>
                </td>
            </tr>
        `;
    }
}

// ===== Search Functionality =====
function setupSearch() {
    const searchInput = document.getElementById('searchInput');
    if (!searchInput) return;

    searchInput.addEventListener('input', function(e) {
        const searchTerm = e.target.value.toLowerCase().trim();
        const rows = document.querySelectorAll('#usersTableBody tr');

        rows.forEach(row => {
            const username = row.querySelector('td:first-child')?.textContent.toLowerCase() || '';
            const shouldShow = username.includes(searchTerm);
            row.style.display = shouldShow ? '' : 'none';
        });
    });
}

// ===== Delete User =====
async function deleteUser(userId, username) {
    if (!confirm(`Are you sure you want to delete user "${username}"?`)) {
        return;
    }

    console.log('🗑️ Deleting user:', userId);

    try {
        const headers = getAuthHeaders();
        if (!headers) return;

        const response = await fetch(`${API_BASE_URL}/users/${userId}`, {
            method: 'DELETE',
            headers: headers
        });

        console.log('📡 Delete response:', response.status);

        if (response.status === 401) {
            throw new Error('Authentication failed. Please login again.');
        }

        if (response.status === 403) {
            throw new Error('Access denied. Admin permissions required.');
        }

        if (response.status === 404) {
            throw new Error('User not found.');
        }

        if (response.status === 204 || response.ok) {
            console.log('✅ User deleted successfully');
            showNotification('User deleted successfully', 'success');
            loadUsers(); // Reload table
        } else {
            const errorData = await response.json().catch(() => ({}));
            throw new Error(errorData.detail || `Server error: ${response.status}`);
        }

    } catch (error) {
        console.error('❌ Delete user error:', error);
        showNotification(error.message, 'danger');
    }
}

// ===== Edit User (Placeholder) =====
function editUser(userId) {
    console.log('✏️ Edit user:', userId);
    showNotification('Edit user feature coming soon!', 'info');
    // TODO: Open modal with user data
}

// ===== Add User (Placeholder) =====
function addUser() {
    console.log('➕ Add new user');
    showNotification('Add user feature coming soon!', 'info');
    // TODO: Open modal for adding user
}

// ===== Notification System =====
function showNotification(message, type = 'info') {
    const icons = {
        success: 'bi-check-circle-fill',
        danger: 'bi-exclamation-triangle-fill',
        info: 'bi-info-circle-fill',
        warning: 'bi-exclamation-circle-fill'
    };

    const colors = {
        success: '#5DD39E',
        danger: '#EF4444',
        info: '#4A90E2',
        warning: '#F59E0B'
    };

    const notification = document.createElement('div');
    notification.className = `alert alert-${type} alert-dismissible fade show`;
    notification.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        z-index: 9999;
        min-width: 300px;
        max-width: 400px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.15);
        border: none;
        border-left: 4px solid ${colors[type]};
    `;

    notification.innerHTML = `
        <i class="bi ${icons[type]} me-2"></i>${message}
        <button type="button" class="btn-close" onclick="this.parentElement.remove()"></button>
    `;

    document.body.appendChild(notification);

    setTimeout(() => {
        notification.classList.remove('show');
        setTimeout(() => notification.remove(), 300);
    }, 4000);
}

// ===== Sidebar Toggle for Mobile =====
function setupMobileMenu() {
    const mobileToggle = document.getElementById('mobileToggle');
    const sidebar = document.getElementById('sidebar');
    const overlay = document.getElementById('sidebarOverlay');

    if (!mobileToggle || !sidebar || !overlay) return;

    mobileToggle.addEventListener('click', () => {
        sidebar.classList.toggle('mobile-visible');
        overlay.classList.toggle('active');
    });

    overlay.addEventListener('click', () => {
        sidebar.classList.remove('mobile-visible');
        overlay.classList.remove('active');
    });
}

// ===== Initialize on Page Load =====
document.addEventListener('DOMContentLoaded', function() {
    console.log('🚀 Users page loaded');

    if (!checkAuth()) {
        r;
    }

    loadUsers();
    setupSearch();
    setupMobileMenu();
});
