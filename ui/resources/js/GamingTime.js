/*global ChartDataLabels, Chart*/
/*from chart.js*/

let gamingData = [];
let selectedYear; let selectedMonth;
let firstYear; let firstMonth
let finalYear; let finalMonth
let chart;
let summaryPeriod = "monthly"
let periodLabel = "Day of Month"
let yearTotalTime;
let monthTotalTime;

$('table')[0].setAttribute('id', 'data-table');

function updatePeriodDisplayWithMonth(selectedYear, selectedMonth) {
    selectedMonth = selectedMonth + 1
    let selectedDate = new Date(`${selectedYear}-${selectedMonth}-1`)
    let monthString = selectedDate.toLocaleDateString("en-US", { year: 'numeric', month: 'long' })
    document.getElementById('time-period-display').innerText = monthString + " : " + parseInt(monthTotalTime) + " Hrs";
    updateWarnMessage("")
}

function updatePeriodDisplayWithYear(selectedYear) {
    document.getElementById('time-period-display').innerText = selectedYear + " : " + parseInt(yearTotalTime) + " Hrs";
    updateWarnMessage("")
}

function updateWarnMessage(message) {
    document.getElementById('warn-msg').innerText = message
}

function updateChart(selectedYear, selectedMonth, yearlySummaryEnabled = false) {

    let labels = [];
    let data = [];
    let datasetData;
    let ylimit;

    if (!yearlySummaryEnabled) {
        monthTotalTime = 0;
        let firstDate = new Date(selectedYear, selectedMonth, 1);
        let lastDate = new Date(selectedYear, selectedMonth + 1, 0);

        for (let date = new Date(firstDate); date <= lastDate; date.setDate(date.getDate() + 1)) {
            labels.push(date.getDate());
            const gamingEntry = gamingData.find(item => {
                const itemDate = new Date(item.date);
                return itemDate.getFullYear() === selectedYear && itemDate.getMonth() === selectedMonth && itemDate.getDate() === date.getDate();
            });
            data.push(gamingEntry ? (gamingEntry.time / 60).toFixed(1) : 0);
            monthTotalTime = monthTotalTime + (gamingEntry ? gamingEntry.time / 60 : 0);
        }

        datasetData = data
        ylimit = 8
    }
    else {
        yearTotalTime = 0;
        labels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

        for (let month = 0; month <= 11; month = month + 1) {
            let monthPlayTime = 0;
            gamingData.find(item => {
                const itemDate = new Date(item.date);
                if (itemDate.getFullYear() === selectedYear && itemDate.getMonth() === month) {
                    monthPlayTime = monthPlayTime + item.time;
                }
            });
            data.push({ "month": labels[month], "time": (monthPlayTime / 60).toFixed(1) });
            yearTotalTime = yearTotalTime + (monthPlayTime / 60)
        }

        datasetData = data.map(row => row.time)
        ylimit = 100
    }

    if (chart) {
        chart.destroy();
    }

    const ctx = document.getElementById('gaming-time-chart').getContext('2d');

    chart = new Chart(ctx, {
        type: 'bar',
        plugins: [ChartDataLabels],
        data: {
            labels: labels,
            datasets: [{
                data: datasetData,
                borderWidth: 2
            }]
        },
        options: {
            scales: {
                y: {
                    beginAtZero: true,
                    max: ylimit,
                    title: {
                        display: true,
                        padding: 15,
                        color: '#000',
                        text: "PlayTime (Hours)",
                        font: {
                            size: 18,
                            family: 'monospace'
                        }
                    }
                },
                x: {
                    title: {
                        display: true,
                        padding: 15,
                        color: '#000',
                        text: periodLabel,
                        font: {
                            size: 18,
                            family: 'monospace'
                        }
                    },
                    ticks: {
                        color: (tickObj) => {
                            const date = new Date(selectedYear, selectedMonth, tickObj['tick']['label'])
                            let day = date.getDay()
                            if (day === 0 || day === 6) {
                                return 'red';
                            }
                        }
                    }
                }
            },
            plugins: {
                tooltip: {
                    enabled: false
                },
                legend: {
                    display: false,
                },
                datalabels: {
                    anchor: "end",
                    align: "top",
                    formatter: function (value) {
                        var formattedValue = ""
                        if (value != 0) {
                            formattedValue = value
                        }
                        return formattedValue;
                    },
                    color: '#000000',
                    font: {
                        family: 'monospace'
                    }
                },
            },
            responsive: true,
            maintainAspectRatio: true
        }
    });
}

function switchToNextMonth() {
    if (selectedMonth === finalMonth && selectedYear === finalYear) {
        updateWarnMessage("No More Data");
        return
    }

    if (selectedMonth === 11) {
        if (selectedYear != finalYear) {
            selectedYear = selectedYear + 1;
            selectedMonth = 0;
        }
    }
    else {
        selectedMonth = selectedMonth + 1
    }
    updateChart(selectedYear, selectedMonth);
    updatePeriodDisplayWithMonth(selectedYear, selectedMonth);

}

function switchToPrevMonth() {
    if (selectedMonth === firstMonth && selectedYear === firstYear) {
        updateWarnMessage("No More Data");
        return
    }

    if (selectedMonth === 0) {
        if (selectedYear != firstYear) {
            selectedYear = selectedYear - 1;
            selectedMonth = 11;
        }
    }
    else {
        selectedMonth = selectedMonth - 1;
    }
    updateChart(selectedYear, selectedMonth);
    updatePeriodDisplayWithMonth(selectedYear, selectedMonth);

}

function switchToNextYear() {
    if (selectedYear === finalYear) {
        updateWarnMessage("No More Data");
        return
    }
    else {
        selectedYear = selectedYear + 1
    }
    updateChart(selectedYear, selectedMonth, true);
    updatePeriodDisplayWithYear(selectedYear);
}

function switchToPrevYear() {
    if (selectedYear === firstYear) {
        updateWarnMessage("No More Data");
        return
    }
    else {
        selectedYear = selectedYear - 1;
    }
    updateChart(selectedYear, selectedMonth, true);
    updatePeriodDisplayWithYear(selectedYear);
}

function toggleSummaryPeriod() {
    document.getElementById('prev-button').replaceWith(document.getElementById('prev-button').cloneNode(true));
    document.getElementById('next-button').replaceWith(document.getElementById('next-button').cloneNode(true));

    if (summaryPeriod === "monthly") {
        document.getElementById('prev-button').addEventListener('click', () => switchToPrevYear());
        document.getElementById('next-button').addEventListener('click', () => switchToNextYear());

        summaryPeriod = "yearly"
        periodLabel = "Month of Year"
        selectedYear = finalYear
        selectedMonth = finalMonth
        document.getElementById('period-button').innerText = "Monthly Summary"

        updateChart(selectedYear, selectedMonth, true);
        updatePeriodDisplayWithYear(selectedYear);
    }
    else {
        document.getElementById('prev-button').addEventListener('click', () => switchToPrevMonth());
        document.getElementById('next-button').addEventListener('click', () => switchToNextMonth());

        summaryPeriod = "monthly"
        periodLabel = "Day of Month"
        selectedYear = finalYear
        selectedMonth = finalMonth
        document.getElementById('period-button').innerText = "Yearly Summary"

        updateChart(selectedYear, selectedMonth);
        updatePeriodDisplayWithMonth(selectedYear, selectedMonth);
    }
}

function loadDataFromTable() {
    const table = document.getElementById('data-table');
    const rows = table.querySelectorAll('tbody tr');

    gamingData = Array.from(rows).map(row => {
        const date = row.cells[0].textContent;
        const time = parseFloat(row.cells[1].textContent);
        return { date, time };
    });

    // Remove header row data
    gamingData.shift()

    // Initialize the chart with the first year in the table
    const firstDate = new Date(gamingData[0].date);
    const lastDate = new Date(gamingData[gamingData.length - 1].date);
    firstYear = parseInt(firstDate.getFullYear())
    firstMonth = parseInt(firstDate.getMonth())
    finalYear = parseInt(lastDate.getFullYear());
    finalMonth = parseInt(lastDate.getMonth());

    selectedYear = finalYear
    selectedMonth = finalMonth

    updateChart(selectedYear, selectedMonth);
    updatePeriodDisplayWithMonth(selectedYear, selectedMonth);
}

document.getElementById('prev-button').addEventListener('click', () => switchToPrevMonth());
document.getElementById('next-button').addEventListener('click', () => switchToNextMonth());

document.getElementById('period-button').addEventListener('click', () => toggleSummaryPeriod());

loadDataFromTable();
