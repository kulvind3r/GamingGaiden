/*global ChartDataLabels, Chart, chartTitleConfig, gamingData*/
/*from chart.js, common.js and html templates*/

let chart;

function updateChart(gameCount, labelText) {
  let labels = [];
  let data = [];

  if (gameCount > gamingData.length) {
    gameCount = gamingData.length;
  }

  let i = 0;
  for (const game of gamingData) {
    if (i == gameCount) break;
    labels.push(game.name);
    data.push({ game: game.name, time: game.time });
    i++;
  }

  if (chart) {
    chart.destroy();
  }

  const ctx = document.getElementById("game-vs-time-chart").getContext("2d");

  chart = new Chart(ctx, {
    type: "bar",
    plugins: [ChartDataLabels],
    data: {
      labels: labels,
      datasets: [
        {
          label: labelText,
          data: data.map((row) => row.time),
          backgroundColor: '#ff6384', // Use a single, consistent color
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
          type: "linear", // Use a standard linear axis
          title: chartTitleConfig(labelText, 15),
        },
      },
      plugins: {
        tooltip: {
          enabled: true,
          callbacks: {
            label: function(context) {
              const value = context.raw;
              const hours = Math.floor(value / 60);
              const minutes = value % 60;
              return `${hours}h ${minutes}m`;
            }
          }
        },
        legend: {
          display: false,
        },
        datalabels: {
          anchor: "end",
          align: "right",
          formatter: function (value) {
            if (value === 0) {
              return "";
            }
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

// Dummy usage of variables to suppress not used false positive in codacy
// without ignoring the entire file.
updateChart;
