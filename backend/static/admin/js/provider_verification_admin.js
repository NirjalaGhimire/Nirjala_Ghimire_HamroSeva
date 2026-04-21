(function () {
  function byId(id) {
    return document.getElementById(id);
  }

  function updateRejectionReasonVisibility() {
    var status = byId('id_verification_status');
    var reason = byId('id_rejection_reason');
    if (!status || !reason) return;
    var row = reason.closest('.form-row') || reason.closest('.field-rejection_reason') || reason.parentElement;
    var isRejected = (status.value || '').toLowerCase() === 'rejected';
    if (row) {
      row.style.display = isRejected ? '' : 'none';
    }
    reason.required = isRejected;
    if (!isRejected) {
      reason.value = '';
    }
  }

  document.addEventListener('DOMContentLoaded', function () {
    var status = byId('id_verification_status');
    if (!status) return;
    status.addEventListener('change', updateRejectionReasonVisibility);
    updateRejectionReasonVisibility();
  });
})();
