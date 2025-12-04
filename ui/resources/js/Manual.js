document.addEventListener('DOMContentLoaded', function() {
  const modal = document.getElementById('modal-overlay');
  const modalBody = document.getElementById('modal-body');
  const closeBtn = document.querySelector('.modal-close');

  // Prevent default details behavior and show modal instead
  document.querySelectorAll('details').forEach(details => {
    details.addEventListener('toggle', function(e) {
      if (this.open) {
        e.preventDefault();

        // Get the content (everything except summary)
        const content = Array.from(this.children)
          .filter(child => child.tagName !== 'SUMMARY')
          .map(child => child.cloneNode(true));

        // Get summary text for modal title
        const summaryText = this.querySelector('summary').textContent;

        // Clear and populate modal
        modalBody.innerHTML = '<h3 class="modal-title">' + summaryText + '</h3>';
        content.forEach(node => modalBody.appendChild(node));

        // Show modal
        modal.classList.add('active');

        // Close the details element
        this.open = false;
      }
    });
  });

  // Close modal on X click
  closeBtn.addEventListener('click', function() {
    modal.classList.remove('active');
  });

  // Close modal on overlay click
  modal.addEventListener('click', function(e) {
    if (e.target === modal) {
      modal.classList.remove('active');
    }
  });

  // Close modal on ESC key
  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape' && modal.classList.contains('active')) {
      modal.classList.remove('active');
    }
  });
});
