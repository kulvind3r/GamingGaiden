$(document).ready(function () {
    const tableBody = $('#games-table tbody');

    if (!gamesData || !Array.isArray(gamesData.games)) {
        console.error("Games data is missing or not in the correct format.");
        return;
    }

    gamesData.games.forEach(game => {
        const safeIconPath = DOMPurify.sanitize(game.IconPath);
        const safeName = DOMPurify.sanitize(game.Name);
        const safePlatform = DOMPurify.sanitize(game.Platform);
        const safePlaytime = DOMPurify.sanitize(game.Playtime);
        const safeSessionCount = DOMPurify.sanitize(game.SessionCount);
        const safeStatusText = DOMPurify.sanitize(game.StatusText);
        const safeStatusIcon = DOMPurify.sanitize(game.StatusIcon);
        const safeLastPlayedOn = DOMPurify.sanitize(game.LastPlayedOn);

        const row = `
            <tr>
                <td><img src="${safeIconPath}" class="game-icon" onerror="this.onerror=null;this.src='resources/images/default.png';"></td>
                <td>${safeName}</td>
                <td>${safePlatform}</td>
                <td>${safePlaytime}</td>
                <td>${safeSessionCount}</td>
                <td><div>${safeStatusText}</div><img src="${safeStatusIcon}"></td>
                <td>${safeLastPlayedOn}</td>
            </tr>
        `;
        tableBody.append(row);
    });

    $('table').DataTable({
        columnDefs: [
          {
            targets: 3,
            className: "playtimegradient",
            render: function (data, type, row, meta) {
              if (type === "display" || type === "filter") {
                var hours = parseInt(parseInt(data) / 60);
                var minutes = parseInt(data) % 60;
                return hours + " Hr " + minutes + " Min";
              }
              return data;
            },
            createdCell: function (td, cellData, rowData, row, col) {
              var maxPlayTime = gamesData.maxPlaytime;
              var percentage = (
                (parseInt(cellData) / maxPlayTime) *
                95
              ).toFixed(2);
              $(td).css("background-size", percentage + "% 85%");
            },
          },
          {
            targets: 6,
            render: function (data, type, row, meta) {
              if (type === "display" || type === "filter") {
                var utcSeconds = parseInt(data);
                var date = new Date(0);
                date.setUTCSeconds(utcSeconds);
                return date.toLocaleDateString(undefined, {
                  year: "numeric",
                  month: "long",
                  day: "numeric",
                });
              }
              return data;
            },
          },
        ],
        order: [
          [6, "desc"],
        ],
        ordering: true,
        paging: "numbers",
        pageLength: 9,
        lengthChange: false,
        searching: true,
    });

    $("#games-table_wrapper")[0].insertAdjacentHTML(
        "afterbegin",
        '<div id="AllGames">All Games\n' + gamesData.totalGameCount + '</div>'
    );
    $("#games-table_wrapper")[0].insertAdjacentHTML(
        "afterbegin",
        '<div id="TotalPlaytime">Total Playtime\n' + gamesData.totalPlaytime + '</div>'
    );

    document
        .getElementById("Toggle-Pagination")
        .addEventListener("click", () => {
        if ($("table").DataTable().page.len() == 9) {
            document.getElementById("Toggle-Pagination").innerText =
            "Paginate";
            $("table").DataTable().page.len(-1).draw();
        } else {
            document.getElementById("Toggle-Pagination").innerText =
            "Show All";
            $("table").DataTable().page.len(9).draw();
        }
    });

    $("#games-table-container").show();
});
