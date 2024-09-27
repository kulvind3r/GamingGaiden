/*global ChartDataLabels, Chart*/
/*from chart.js*/

let gamingData = [];
let chart;
let gameCount = 10;

$('table')[0].setAttribute('id', 'data-table');

function updateChart(gameCount) {

    let labels = [];
    let data = [];

    if (gameCount > gamingData.length) {
        gameCount = gamingData.length
    }

    let i = 0
    for (const game of gamingData) {
        if (i == gameCount) break;
        labels.push(game.name)
        data.push({ "game": game.name, "time": (game.time / 60).toFixed(1) });
        i++
    }

    if (chart) {
        chart.destroy();
    }

    const ctx = document.getElementById('most-played-chart').getContext('2d');

    chart = new Chart(ctx, {
        type: 'bar',
        plugins: [ChartDataLabels],
        data: {
            labels: labels,
            datasets: [{
                label: 'Playtime (Hours)',
                data: data.map(row => row.time),
                borderWidth: 2
            }]
        },
        options: {
            indexAxis: 'y',
            scales: {
                y: {
                    ticks: {
                        autoSkip: false
                    }
                },
                // Alignment Hack: Add an identical y scale on right side, to center the graph on page.
                // Then hide the right side scale by setting label color identical to background.
                yRight: {
                    position: 'right',
                    grid: {
                        display: false
                    },
                    ticks: {
                        color: 'white'
                    }
                },
                x: {
                    ticks: {
                        stepSize: 10
                    },
                    title: chartTitleConfig("Playtime (Hours)", 15)
                }
            },
            elements: {
                bar: {
                    borderWidth: 1,
                }
            },
            responsive: true,
            plugins: {
                tooltip: {
                    enabled: false
                },
                legend: {
                    display: false
                },
                datalabels: {
                    anchor: "end",
                    align: "right",
                    color: '#000000',
                    font: {
                        family: 'monospace'
                    }
                }
            },
            maintainAspectRatio: true
        }
    });
}

function loadDataFromTable() {
    const table = document.getElementById('data-table');
    const rows = table.querySelectorAll('tbody tr');

    gamingData = Array.from(rows).map(row => {
        const name = row.cells[0].textContent;
        const time = parseFloat(row.cells[1].textContent);
        return { name, time };
    });

    // Remove header row data
    gamingData.shift()

    var selectBox = document.getElementById('game-count');
    const maxOptions = Math.min(50, gamingData.length);

    // Loop to generate options
    for (let i = 10; i <= maxOptions; i += 10) {
        const option = document.createElement('option');
        option.value = i;
        option.text = i;
        selectBox.add(option);
    }

    if (gamingData.length < 50) {
        const showAllOption = document.createElement('option');
        showAllOption.value = gamingData.length;
        showAllOption.text = gamingData.length;
        selectBox.add(showAllOption);
    }

    updateChart(gameCount);
}

document.getElementById('game-count').addEventListener('change', () => { updateChart(document.getElementById('game-count').value); });

loadDataFromTable();
