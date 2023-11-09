let gamingData = [];
let chart;
let gameCount = 10;

$('table')[0].setAttribute('id','data-table');

function updateChart(gameCount) {
    
    let labels = [];
    let data = [];

    for (i=1; i<=gameCount; i++)
    {
        labels.push(gamingData[i].name)
        data.push({"game":gamingData[i].name, "time": (gamingData[i].time / 60).toFixed(1) });
    }
    
    if (chart) {
        chart.destroy();
    }

    const ctx = document.getElementById('most-played-chart').getContext('2d');
    
    chart = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: labels,
            datasets: [{
                label: 'Game Time (hours)',
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
                x: {
                    ticks: {
                      stepSize: 10
                    }
                  }
              },
            elements: {
                bar: {
                  borderWidth: 1,
                }
              },
            responsive: true, // Make the chart responsive
            plugins: {
                legend: {
                  position: 'right',
                },
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

    updateChart(gameCount);
}

document.getElementById('game-count').addEventListener('change', () => { updateChart(document.getElementById('game-count').value); });

loadDataFromTable();
