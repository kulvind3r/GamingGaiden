$(document).ready(function() {
    // This script initializes the DataTable for the session history page,
    // making the table of recent sessions sortable and searchable.

    const tableBody = $('#sessionHistoryTable tbody');

    if (!sessionData || !Array.isArray(sessionData)) {
        console.error("Session data is missing or not in the correct format.");
        return;
    }

    // Loop through each session record passed from the PowerShell script
    sessionData.forEach(session => {
        // Sanitize data before inserting it into the DOM to prevent XSS attacks
        const safeGameName = DOMPurify.sanitize(session.GameName);
        const safeIconPath = DOMPurify.sanitize(session.IconPath);
        const safeDuration = DOMPurify.sanitize(session.Duration);
        const safeStartDate = DOMPurify.sanitize(session.StartDate);
        const safeStartTime = DOMPurify.sanitize(session.StartTime);

        // Create the HTML for the new table row
        const row = `
            <tr>
                <td>
                    <div class="game-cell">
                        <img src="${safeIconPath}" class="game-icon" onerror="this.onerror=null;this.src='resources/images/default.png';">
                        <span>${safeGameName}</span>
                    </div>
                </td>
                <td>${safeDuration}</td>
                <td>${safeStartDate}</td>
                <td>${safeStartTime}</td>
            </tr>
        `;
        // Append the new row to the table body
        tableBody.append(row);
    });

    // Initialize the DataTable plugin on the table
    $('#sessionHistoryTable').DataTable({
        // Set the default sort order to descending by date, then by time
        "order": [[ 2, "desc" ], [3, "desc"]],
        "pageLength": 25,
        "lengthMenu": [ [10, 25, 50, -1], [10, 25, 50, "All"] ],
        "columnDefs": [
            // Define properties for each column
            { "targets": 0, "orderable": true, "searchable": true }, // Game
            { "targets": 1, "orderable": false, "searchable": false }, // Duration
            { "targets": 2, "orderable": true, "searchable": true }, // Date
            { "targets": 3, "orderable": true, "searchable": false }  // Time
        ]
    });
});
