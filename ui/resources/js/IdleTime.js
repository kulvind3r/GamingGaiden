let gamingData = [];
let chart;

$('table')[0].setAttribute('id','data-table');

function updateChart() {
    
    let labels = [];
    let data = [];
    
    for (i=0; i<gamingData.length; i++)
    {
        labels.push(gamingData[i].name)
        data.push({"game":gamingData[i].name, "time": gamingData[i].time });
    }
    
    if (chart) {
        chart.destroy();
    }
    
    const ctx = document.getElementById('idle-time-chart').getContext('2d');
    
    chart = new Chart(ctx, {
        type: 'bar',
        plugins: [ChartDataLabels],
        data: {
            labels: labels,
            datasets: [{
                label: 'Idle Time (Minutes)',
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
                        stepSize: 5
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
                tooltip: {
                    enabled: false
                },
                legend: {
                    onClick: null,
                    labels: {
                        font: {
                            size: 15,
                            family: 'monospace'
                        }
                    }
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
    
    updateChart();
}

loadDataFromTable();
