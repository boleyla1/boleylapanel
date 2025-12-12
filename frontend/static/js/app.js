const API_URL = 'http://localhost:8000';

// Mobile Menu Toggle
const mobileToggle = document.getElementById('mobileToggle');
const sidebar = document.getElementById('sidebar');
const sidebarOverlay = document.getElementById('sidebarOverlay');

mobileToggle.addEventListener('click', function() {
    sidebar.classList.toggle('mobile-visible');
    sidebarOverlay.classList.toggle('active');
});

sidebarOverlay.addEventListener('click', function() {
    sidebar.classList.remove('mobile-visible');
    sidebarOverlay.classList.remove('active');
});

// Load Dashboard Stats
async function loadDashboardStats() {
    try {
        const response = await fetch(`${API_URL}/api/stats`);
        const stats = await response.json();

        document.getElementById('totalUsers').textContent = stats.total_users || 0;
        document.getElementById('activeUsers').textContent = stats.active_users || 0;
        document.getElementById('totalInbounds').textContent = stats.total_inbounds || 0;
        document.getElementById('totalTraffic').textContent =
            ((stats.total_traffic || 0) / 1073741824).toFixed(2) + ' GB';

    } catch (error) {
        console.error('Error loading stats:', error);
    }
}

// Line Chart - Traffic Overview
const lineCtx = document.getElementById('lineChart').getContext('2d');
const lineChart = new Chart(lineCtx, {
    type: 'line',
    data: {
        labels: ['Jan 01', 'Jan 02', 'Jan 03', 'Jan 04', 'Jan 05', 'Jan 06', 'Jan 07'],
        datasets: [{
            label: 'Traffic (GB)',
            data: [12, 19, 25, 22, 28, 24, 30],
            borderColor: '#4A90E2',
            backgroundColor: 'rgba(74, 144, 226, 0.1)',
            tension: 0.4,
            fill: true,
            pointRadius: 0,
            borderWidth: 2
        }]
    },
    options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
            legend: {
                display: false
            },
            tooltip: {
                mode: 'index',
                intersect: false,
                backgroundColor: 'rgba(255, 255, 255, 0.95)',
                titleColor: '#212529',
                bodyColor: '#6C757D',
                borderColor: '#E9ECEF',
                borderWidth: 1,
                padding: 12
            }
        },
        scales: {
            y: {
                beginAtZero: true,
                grid: {
                    color: '#F8F9FA',
                    drawBorder: false
                },
                ticks: {
                    color: '#6C757D',
                    font: { size: 11 }
                }
            },
            x: {
                grid: {
                    display: false,
                    drawBorder: false
                },
                ticks: {
                    color: '#6C757D',
                    font: { size: 11 }
                }
            }
        }
    }
});

// Donut Chart - User Distribution
const donutCtx = document.getElementById('donutChart').getContext('2d');
const donutChart = new Chart(donutCtx, {
    type: 'doughnut',
    data: {
        labels: ['Active', 'Inactive', 'Expired'],
        datasets: [{
            data: [45, 25, 30],
            backgroundColor: ['#4A90E2', '#8B5CF6', '#5DD39E'],
            borderWidth: 0,
            spacing: 2
        }]
    },
    options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
            legend: {
                display: false
            },
            tooltip: {
                backgroundColor: 'rgba(255, 255, 255, 0.95)',
                titleColor: '#212529',
                bodyColor: '#6C757D',
                borderColor: '#E9ECEF',
                borderWidth: 1,
                padding: 12
            }
        },
        cutout: '70%'
    }
});

// Load data on page load
document.addEventListener('DOMContentLoaded', loadDashboardStats);
