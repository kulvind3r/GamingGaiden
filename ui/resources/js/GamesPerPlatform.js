/*global ChartDataLabels, Chart, chartTooltipConfig, chartLegendConfig, chartDataLabelFontConfig, buildGamingData*/
/*from chart.js, common.js*/
let gamingData = [];

$('table')[0].setAttribute('id', 'data-table');

function updateChart() {

    const ctx = document.getElementById('games-per-platform-chart').getContext('2d');

    new Chart(ctx, {
        type: 'doughnut',
        plugins: [ChartDataLabels],
        data: {
            labels: gamingData.map(row => row.name),
            datasets: [{
                data: gamingData.map(row => row.count),
                borderWidth: 2,
                backgroundColor: ["#1ea1e6", "#ff6481", "#3dbebe", "#ff9d4c", "#9669f8", "#ffca63", "#c7c9cd", "#4e79a7", "#bc80bd", "#ff9da7", "#fb8072", "#a0cbe8", "#bebada"]
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            plugins: {
                tooltip: chartTooltipConfig,
                legend: chartLegendConfig,
                datalabels: {
                    color: '#000000',
                    font: chartDataLabelFontConfig
                }
            }
        }
    });
}

function loadDataFromTable() {
    gamingData = buildGamingData("name", "count")
    updateChart();
}

loadDataFromTable();
