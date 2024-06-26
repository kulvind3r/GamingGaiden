let gamingData = [];
let chart;

$('table')[0].setAttribute('id', 'data-table');

function updateChart(gameCount) {

    const ctx = document.getElementById('pc-vs-emulation-chart').getContext('2d');

    chart = new Chart(ctx, {
        type: 'pie',
        plugins: [ChartDataLabels],
        data: {
            labels: gamingData.map(row => row.platform),
            datasets: [{
                data: gamingData.map(row => row.play_time),
                borderWidth: 2
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            plugins: {
                tooltip: {
                    displayColors: false,
                    yAlign: 'top',
                    caretPadding: 7,
                    callbacks: {
                        label: function (context) {
                            return ''
                        }
                    }
                },
                legend: {
                    onClick: null,
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
                    formatter: function (value) {
                        return value + ' Hrs';
                    },
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
        const platform = row.cells[0].textContent;
        const play_time = (parseInt(row.cells[1].textContent) / 60).toFixed(1);
        return { platform, play_time };
    });

    // Remove header row data
    gamingData.shift()
    updateChart();
}

loadDataFromTable();
