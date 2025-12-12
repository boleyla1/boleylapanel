// js/login.js - نسخه نهایی با حل مشکل Redirect

document.addEventListener('DOMContentLoaded', function() {
    // ✅ چک کردن: اگر قبلاً لاگین کرده، بفرست به dashboard
    const existingToken = localStorage.getItem('access_token');
    if (existingToken) {
        console.log('🔄 Already authenticated, redirecting...');
        window.location.replace('index.html');
        return;
    }

    const loginForm = document.getElementById('loginForm');
    if (loginForm) {
        loginForm.addEventListener('submit', handleLogin);
    }
});

async function handleLogin(event) {
    event.preventDefault();

    const identifier = document.getElementById('identifier').value.trim();
    const password = document.getElementById('password').value.trim();
    const button = event.target.querySelector('button[type="submit"]');

    // Validation
    if (!identifier || !password) {
        showError('لطفاً تمام فیلدها را پر کنید');
        return;
    }

    // UI Loading State
    const originalText = button.innerHTML;
    button.disabled = true;
    button.innerHTML = '<i class="bi bi-hourglass-split"></i> در حال ورود...';

    try {
        console.log('🔄 Attempting login with:', identifier);

        const response = await fetch('http://localhost:8000/api/v1/auth/login', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: new URLSearchParams({
                'username': identifier,
                'password': password
            })
        });

        console.log('📡 Response status:', response.status);

        if (!response.ok) {
            const errorData = await response.json().catch(() => ({}));

            // مدیریت خطاهای خاص
            if (response.status === 401) {
                throw new Error('نام کاربری یا رمز عبور اشتباه است');
            } else if (response.status === 422) {
                throw new Error('فرمت ورودی نامعتبر است');
            } else if (response.status === 404) {
                throw new Error('مسیر API یافت نشد. لطفاً تنظیمات را چک کنید');
            }

            throw new Error(errorData.detail || `خطای سرور: ${response.status}`);
        }

        const data = await response.json();
        console.log('✅ Login successful:', data);

        // ✅ ذخیره توکن‌ها
        localStorage.setItem('access_token', data.access_token);
        localStorage.setItem('token_type', data.token_type || 'bearer');

        if (data.refresh_token) {
            localStorage.setItem('refresh_token', data.refresh_token);
        }

        // ذخیره اطلاعات کاربر (اگر API برگردونه)
        if (data.username) {
            localStorage.setItem('username', data.username);
        }

        // Success UI
        button.innerHTML = '<i class="bi bi-check-circle"></i> ورود موفق!';
        button.classList.remove('btn-primary');
        button.classList.add('btn-success');

        // ✅ Redirect با replace (برای جلوگیری از برگشت با دکمه Back)
        setTimeout(() => {
            console.log('🚀 Redirecting to dashboard...');
            window.location.replace('index.html');
        }, 800);

    } catch (error) {
        console.error('❌ Login error:', error);
        showError(error.message);

        // Reset button state
        button.disabled = false;
        button.innerHTML = originalText;
        button.classList.remove('btn-success');
        button.classList.add('btn-primary');
    }
}

function showError(message) {
    // حذف alert های قبلی
    const existingAlerts = document.querySelectorAll('.alert-danger');
    existingAlerts.forEach(alert => alert.remove());

    // ساخت alert جدید
    const alertDiv = document.createElement('div');
    alertDiv.className = 'alert alert-danger alert-dismissible fade show';
    alertDiv.style.cssText = 'position: fixed; top: 20px; right: 20px; z-index: 9999; min-width: 300px; box-shadow: 0 4px 12px rgba(0,0,0,0.15);';
    alertDiv.innerHTML = `
        <i class="bi bi-exclamation-triangle-fill me-2"></i>
        <strong>خطا!</strong> ${message}
        <button type="button" class="btn-close" onclick="this.parentElement.remove()"></button>
    `;
    document.body.appendChild(alertDiv);

    // Auto-remove after 5 seconds
    setTimeout(() => {
        if (alertDiv.parentElement) {
            alertDiv.classList.remove('show');
            setTimeout(() => alertDiv.remove(), 150);
        }
    }, 5000);
}

// ✅ دکمه Logout (برای استفاده در صفحات دیگر)
function logout() {
    if (confirm('آیا می‌خواهید از حساب کاربری خارج شوید؟')) {
        console.log('🚪 Logging out...');
        localStorage.clear();
        window.location.replace('login.html');
    }
}
