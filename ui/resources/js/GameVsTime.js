/*global ChartDataLabels, Chart, chartTitleConfig */
/*from chart.js, common.js*/

let chart;

function updateChart(gameCount, labelText, stepSize = 1) {

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

    const ctx = document.getElementById('game-vs-time-chart').getContext('2d');

    chart = new Chart(ctx, {
        type: 'bar',
        plugins: [ChartDataLabels],
        data: {
            labels: labels,
            datasets: [{
                label: labelText,
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
                        stepSize: stepSize
                    },
                    title: chartTitleConfig(labelText, 15)
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