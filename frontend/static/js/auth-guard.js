// js/auth-guard.js - محافظ احراز هویت

(function() {
    'use strict';

    const token = localStorage.getItem('access_token');
    const currentPage = window.location.pathname.split('/').pop() || 'index.html';

    // صفحاتی که نیاز به لاگین ندارند
    const publicPages = ['login.html'];

    // ✅ صفحه خصوصی + بدون توکن = برو login
    if (!publicPages.includes(currentPage) && !token) {
        console.warn('⚠️ Unauthorized access, redirecting to login...');
        window.location.replace('login.html');
        return;
    }

    // ✅ صفحه login + دارای توکن = برو dashboard
    if (currentPage === 'login.html' && token) {
        console.log('✅ Already logged in, redirecting to dashboard...');
        window.location.replace('index.html');
        return;
    }

    console.log('✅ Auth check passed for:', currentPage);
})();
