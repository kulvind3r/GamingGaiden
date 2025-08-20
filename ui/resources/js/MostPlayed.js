/*global ChartDataLabels, Chart, chartTitleConfig, gamingData*/
/*from chart.js, common.js and html templates*/

let mostPlayedChart;

function updateMostPlayedChart(gameCount) {
  // Ensure gamingData is available
  if (typeof gamingData === 'undefined' || gamingData.length === 0) {
    return;
  }

  const labels = [];
  const data = [];
  const colors = [];

  const displayData = gamingData.slice(0, gameCount);

  for (const game of displayData) {
    labels.push(game.name);
    const hours = Math.floor(game.time / 60);
    const minutes = game.time % 60;
    data.push(game.time); // Keep data in minutes for processing
    colors.push(game.color_hex || '#cccccc'); // Use default color if null
  }

  if (mostPlayedChart) {
    mostPlayedChart.destroy();
  }

  const ctx = document.getElementById("most-played-chart-canvas").getContext("2d");

  mostPlayedChart = new Chart(ctx, {
    type: "bar",
    plugins: [ChartDataLabels],
    data: {
      labels: labels,
      datasets: [
        {
          label: "Playtime",
          data: data,
          backgroundColor: colors,
          borderWidth: 1,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      indexAxis: "y",
      scales: {
        y: {
          ticks: {
            autoSkip: false,
            font: {
              size: 14,
            }
          },
        },
        x: {
          type: "linear",
          title: chartTitleConfig("Playtime (Hours)", 15),
          ticks: {
            stepSize: 60,
            precision: 0,
            callback: function(value) {
                // Display ticks as hours
                return Math.floor(value / 60);
            }
          }
        },
      },
      plugins: {
        legend: {
          display: false,
        },
        tooltip: {
          enabled: true, // Enable tooltips for better UX
          callbacks: {
            label: function(context) {
              const value = context.raw;
              const hours = Math.floor(value / 60);
              const minutes = value % 60;
              return `${hours}h ${minutes}m`;
            }
          }
        },
        datalabels: {
          anchor: "end",
          align: "right",
          formatter: function (value) {
            if (value === 0) return "";
            const hours = Math.floor(value / 60);
            const minutes = value % 60;
            return `${hours}h ${minutes}m`;
          },
          color: "#000000",
          font: {
            family: "monospace",
          },
        },
      }
    },
  });
}
