/*global Chart, buildGamingData, chartTitleConfig, ChartDataLabels, DOMPurify*/
/*from chart.js, common.js, purify.min.js*/

let gamingData = [];
let pcData = [];
let annualHoursData = buildGamingData(
  "Year",
  "TotalPlayTime",
  "annual-gaming-hours-table",
  "table"
);
let currentPCIndex = 0;
let finishedCount = 0;
let inProgressCount = 0;
let holdCount = 0;
let foreverCount = 0;
let droppedCount = 0;

// Create custom log axis in base 2
class Log2Axis extends Chart.Scale {
  constructor(cfg) {
    super(cfg);
    this._startValue = undefined;
    this._valueRange = 0;
  }

  parse(raw, index) {
    const value = Chart.LinearScale.prototype.parse.apply(this, [raw, index]);
    return isFinite(value) && value > 0 ? value : null;
  }

  determineDataLimits() {
    const { min, max } = this.getMinMax(true);
    this.min = isFinite(min) ? Math.max(0, min) : null;
    this.max = isFinite(max) ? Math.max(0, max) : null;
  }

  buildTicks() {
    const ticks = [];

    let power = Math.floor(Math.log2(this.min || 1));
    let maxPower = Math.ceil(Math.log2(this.max || 2));
    while (power <= maxPower) {
      ticks.push({
        value: Math.pow(2, power),
      });
      power += 1;
    }

    this.min = ticks[0].value;
    this.max = ticks[ticks.length - 1].value;
    return ticks;
  }

  /**
   * @protected
   */
  configure() {
    const start = this.min;

    super.configure();

    this._startValue = Math.log2(start);
    this._valueRange = Math.log2(this.max) - Math.log2(start);
  }

  getPixelForValue(value) {
    if (value === undefined || value === 0) {
      value = this.min;
    }

    return this.getPixelForDecimal(
      value === this.min ? 0 : (Math.log2(value) - this._startValue) / this._valueRange
    );
  }

  getValueForPixel(pixel) {
    const decimal = this.getDecimalForPixel(pixel);
    return Math.pow(2, this._startValue + decimal * this._valueRange);
  }
}

Log2Axis.id = "log2";
Log2Axis.defaults = {};

Chart.register(Log2Axis);

function updateSummayChart() {
  const ctx = document
    .getElementById("session-vs-playtime-chart")
    .getContext("2d");

  new Chart(ctx, {
    type: "scatter",
    data: {
      labels: gamingData.map((row) => row.name),
      datasets: [
        {
          data: gamingData.map((row) => ({
            x: row.sessions,
            y: row.playtime,
            completed: row.completed,
            status: row.status,
          })),
          borderWidth: 2,
          pointBackgroundColor: function (context) {
            var valueCompleted = context.raw.completed;
            if (valueCompleted == "FALSE") {
              return "#a6cbf5";
            } else {
              var valueStatus = context.raw.status;
              if (valueStatus == "") {
                return "#59eb8a";
              }
              if (valueStatus == "hold") {
                return "#f5c37d";
              }
              if (valueStatus == "forever") {
                return "#d0d3db";
              }
              if (valueStatus == "dropped") {
                return "#deb297";
              }
            }
          },
          pointBorderColor: function (context) {
            var valueCompleted = context.raw.completed;
            if (valueCompleted == "FALSE") {
              return "#1f9afe";
            } else {
              var valueStatus = context.raw.status;
              if (valueStatus == "") {
                return "#059b27";
              }
              if (valueStatus == "hold") {
                return "#d78f34";
              }
              if (valueStatus == "forever") {
                return "#94979c";
              }
              if (valueStatus == "dropped") {
                return "#662f13";
              }
            }
          },
        },
      ],
    },
    options: {
      scales: {
        y: {
          type: "log2",
          title: chartTitleConfig("PlayTime (Hours)"),
        },
        x: {
          title: chartTitleConfig("Game Sessions", 15),
          ticks: {
            stepSize: 10,
          },
        },
      },
      elements: {
        point: {
          radius: 3.5,
          hoverRadius: 4.5,
        },
      },
      plugins: {
        tooltip: {
          enabled: true,
          mode: "nearest",
          caretPadding: 7,
          displayColors: false,
          callbacks: {
            label: function (context) {
              let label =
                context.parsed.y +
                " hrs over " +
                context.parsed.x +
                " sessions";
              return label;
            },
          },
        },
        legend: {
          display: false,
        },
      },
      responsive: true,
      maintainAspectRatio: false,
    },
  });
}

function loadSummaryDataFromTable() {
  const summaryTable = $("#summary-table").find("table");
  const summaryRows = summaryTable.find("tbody tr");

  gamingData = Array.from(summaryRows).map((row) => {
    const name = row.cells[0].textContent;
    const playtime = (parseFloat(row.cells[1].textContent) / 60).toFixed(1);
    const sessions = parseFloat(row.cells[2].textContent);
    const completed = row.cells[3].textContent;
    const status = row.cells[4].textContent;

    completed == "FALSE" ? inProgressCount++ : finishedCount++;
    if (status == "hold") {
      holdCount++;
    }
    if (status == "forever") {
      foreverCount++;
    }
    if (status == "dropped") {
      droppedCount++;
    }

    return { name, playtime, sessions, completed, status };
  });

  // Remove header row data, deduct one extra game added to finished count due to header row
  gamingData.shift();
  finishedCount--;

  let gameProgressMsg = inProgressCount > 1 ? " Games In Progress" : " Game In Progress";
  let gameFinishedMsg = finishedCount > 1 ? " Games Finished" : " Game Finished";
  let gameHoldMsg     = holdCount > 1 ? " Games on Hold" : " Game on Hold";
  let gameForeverMsg  = foreverCount > 1 ? " Forever Games" : " Forever Game";
  let gameDroppedMsg  = droppedCount > 1 ? " Dropped Games " : " Dropped Game";

  $("#progress-count").text(inProgressCount + gameProgressMsg);
  $("#finished-count").text(finishedCount + gameFinishedMsg);
  $("#hold-count").text(holdCount + gameHoldMsg);
  $("#forever-count").text(foreverCount + gameForeverMsg);
  $("#dropped-count").text(droppedCount + gameDroppedMsg);
}

function loadPCDataFromTable() {
  const pcTable = document.getElementById("pc-table").querySelector("table");
  const pcRows = pcTable.querySelectorAll("tbody tr");

  pcData = Array.from(pcRows).map((row) => {
    const iconUri = DOMPurify.sanitize(row.cells[0].innerHTML);
    const name = row.cells[1].textContent;
    const current = row.cells[2].textContent;
    const cost = row.cells[3].textContent;
    const currency = row.cells[4].textContent;

    let utcSecondsStartDate = parseInt(row.cells[5].textContent);
    let s_date = new Date(0);
    s_date.setUTCSeconds(utcSecondsStartDate);
    const start_date = s_date.toLocaleDateString(undefined, {
      year: "numeric",
      month: "long",
    });

    let end_date = "";
    if (current != "TRUE") {
      let utcSecondsEndDate = parseInt(row.cells[6].textContent);
      let e_date = new Date(0);
      e_date.setUTCSeconds(utcSecondsEndDate);
      end_date = e_date.toLocaleDateString(undefined, {
        year: "numeric",
        month: "long",
      });
    } else {
      end_date = "";
    }

    const age = row.cells[7].textContent;
    const totalHours = row.cells[8].textContent;

    return {
      iconUri,
      name,
      current,
      cost,
      currency,
      start_date,
      end_date,
      age,
      totalHours,
    };
  });

  // Remove header row data
  pcData.shift();
}

function updatePCStatsSection(pcData) {
  let valuePerHour = Math.floor(
    parseInt(pcData.cost) / parseInt(pcData.totalHours)
  );
  let ageInMonths = parseInt(pcData.age.split(" ")[0]) * 12 +
                    parseInt(pcData.age.split(" ")[3]);
  let valuePerMonth = Math.floor(parseInt(pcData.cost) / ageInMonths);

  document.getElementById("pc-name").innerText = pcData.name;

  // Use DomPurify with Jquery $().html() instead of plain document.getElementByID().innerHTML()
  // to prevent Codacy from triggering false positives for XSS attack vulnerabilities.
  $("#pc-icon").html(DOMPurify.sanitize(pcData.iconUri));

  $("#pc-in-use").html(DOMPurify.sanitize("<b>In Use: </b>" + pcData.start_date + " - " + pcData.end_date));
  if (pcData.current == "TRUE") {
    $("#pc-in-use").html(DOMPurify.sanitize("<b>In Use: </b>" + pcData.start_date + " - Present"));
  }

  $("#pc-lifespan").html(DOMPurify.sanitize("<b>Lifespan: </b>" + pcData.age));
  $("#pc-price").html(DOMPurify.sanitize("<b>Price: </b>" + pcData.currency + pcData.cost));
  $("#pc-hours").html(DOMPurify.sanitize("<b>Hours Logged: </b>" + pcData.totalHours + "<sup> ✞</sup>"));
  $("#pc-running-cost").html(DOMPurify.sanitize("<b>Running Cost: </b>" + pcData.currency + valuePerHour + "/Hour | " + pcData.currency + valuePerMonth + "/Month"));
}

function updateAnnualHoursChart() {
  const ctx = document
    .getElementById("year-vs-playtime-chart")
    .getContext("2d");

  new Chart(ctx, {
    type: "pie",
    plugins: [ChartDataLabels],
    data: {
      labels: annualHoursData.map((row) => row.Year),
      datasets: [
        {
          data: annualHoursData.map((row) => row.TotalPlayTime),
          borderWidth: 2,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        title: {
          text: "Annual Hours Played",
          display: true,
          position: "bottom",
          color: "#000000",
          font: {
            size: 18,
            family: "monospace",
            weight: "normal",
          },
        },
        tooltip: { enabled: false },
        legend: { display: false },
        datalabels: {
          formatter: function (value, context) {
            return (
              context.chart.data.labels[context.dataIndex] +
              "\n" +
              Math.floor(value) +
              " Hrs"
            );
          },
          textAlign: "center",
          color: "#000000",
          font: {
            size: 14,
            family: "monospace",
          },
        },
      },
    },
  });
}

document.getElementById("prev-button").addEventListener("click", () => {
  currentPCIndex = currentPCIndex - 1;
  if (currentPCIndex < 0) {
    currentPCIndex = pcData.length - 1; // Loop back to last element
  }
  updatePCStatsSection(pcData.at(currentPCIndex));
});

document.getElementById("next-button").addEventListener("click", () => {
  currentPCIndex = currentPCIndex + 1;
  if (currentPCIndex == pcData.length) {
    currentPCIndex = 0; // Loop back to first element
  }
  updatePCStatsSection(pcData.at(currentPCIndex));
});

loadSummaryDataFromTable();
loadPCDataFromTable();

if (pcData.length > 0) {
  updatePCStatsSection(pcData.at(currentPCIndex));
} else {
  $("#pc-icon").html(DOMPurify.sanitize('<img src=".\\resources\\images\\pc.png"></img>'));
  document.getElementById("pc-icon").querySelector("img").style.border = "none";
  document.getElementById("pc-navigation-bar").style.display = "none";
  document.getElementById("pc-status").textContent = "Add Gaming PCs to see more stats";
}

updateAnnualHoursChart();
updateSummayChart();
