let gamingData = [];
let chart;

$('table')[0].setAttribute('id','data-table');

function updateChart(gameCount) {

    const ctx = document.getElementById('games-per-platform-chart').getContext('2d');
    
    chart = new Chart(ctx, {
        type: 'doughnut',
        plugins: [ChartDataLabels],
        data: {
            labels: gamingData.map(row => row.name),
            datasets: [{
                data: gamingData.map(row => row.count),
                borderWidth: 2,
                backgroundColor: ["#1ea1e6","#ff6481","#3dbebe","#ff9d4c","#9669f8","#ffca63","#c7c9cd","#4e79a7","#bc80bd","#ff9da7","#fb8072","#a0cbe8","#bebada"]
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            plugins: {
                tooltip: {
                    enabled: false
                },
                legend: {
                    position: 'bottom',
                    labels: {
                        boxWidth: 20,
                        padding: 40,
                        font: {
                            size: 18,
                            weight: 'bold',
                            family: 'monospace'
                        }
                    }
                },
                datalabels: {
                    color: '#000000',
                    font: {
                        size: 18,
                        weight: 'bold',
                        family: 'monospace'
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
