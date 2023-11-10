let gamingData = [];
let chart;

$('table')[0].setAttribute('id','data-table');

function updateChart(gameCount) {

    const ctx = document.getElementById('games-per-platform-chart').getContext('2d');
    
    chart = new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: gamingData.map(row => row.name),
            datasets: [{
                data: gamingData.map(row => row.count),
                borderWidth: 2
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            plugins: {
                legend: {
                position: 'bottom',
                labels: {
                    boxWidth: 20,
                    padding: 40,
                    font: {
                        size: 18
                    }
                }
              }
            }
        }
    });
}

function loadDataFromTable() {
    const table = document.getElementById('data-table');
    const rows = table.querySelectorAll('tbody tr');

    gamingData = Array.from(rows).map(row => {
        const name = row.cells[0].textContent;
        const count = parseFloat(row.cells[1].textContent);
        return { name, count };
    });

    // Remove header row data
    gamingData.shift()
    updateChart();
}

loadDataFromTable();
