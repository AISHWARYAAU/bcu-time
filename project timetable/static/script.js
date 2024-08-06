document.addEventListener("DOMContentLoaded", function() {
    var startButton = document.getElementById('startButton');
    if (startButton) {
        startButton.addEventListener('click', function() {
            window.location.href = '/admin_login';
        });
    }
});