let gamingData = [];
let selectedYear; let selectedMonth;
let firstYear; let firstMonth
let finalYear; let finalMonth
let chart;
let summaryPeriod = "monthly"

$('table')[0].setAttribute('id','data-table');

function updatePeriodDisplayWithMonth(selectedYear, selectedMonth) {
    selectedMonth = selectedMonth + 1
    selectedDate = new Date(`${selectedYear}-${selectedMonth}`)
    document.getElementById('time-period-display').innerText = selectedDate.toLocaleDateString("en-US",{ year: 'numeric', month: 'long'})
    updateWarnMessage("")
}

function updatePeriodDisplayWithYear(selectedYear) {
    document.getElementById('time-period-display').innerText = selectedYear
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

    if (!yearlySummaryEnabled)
    {
        let firstDate = new Date(selectedYear, selectedMonth, 1);
        let lastDate = new Date(selectedYear, selectedMonth + 1, 0);
        
        for (let date = new Date(firstDate); date <= lastDate; date.setDate(date.getDate() + 1)) {
            labels.push(date.getDate());
            const gamingEntry = gamingData.find(item => {
                const itemDate = new Date(item.date);
                return itemDate.getFullYear() === selectedYear && itemDate.getMonth() === selectedMonth && itemDate.getDate() === date.getDate();
            });
            data.push(gamingEntry ? gamingEntry.time / 60 : 0); // Convert minutes to hours
        }

        datasetData = data
        ylimit = 8
    }
    else
    {
        labels = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']

        for (let month = 0; month <= 11; month = month +1) {
            let monthPlayTime = 0;
            gamingData.find(item => {                
                const itemDate = new Date(item.date);
                if(itemDate.getFullYear() === selectedYear && itemDate.getMonth() === month){
                    monthPlayTime = monthPlayTime + item.time;
                }
            });
            data.push({"month":labels[month], "time": monthPlayTime / 60 }); // Convert minutes to hours
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
        data: {
            labels: labels,
            datasets: [{
                label: 'Time Spent Gaming (hours)',
                data: datasetData,
                borderWidth: 2
            }]
        },
        options: {
            animation: {
                duration: 0
            },
            scales: {
                y: {
                    beginAtZero: true,
                    max: ylimit,
                    callback: (value) => value + ' hrs'
                }
            },
            responsive: true, // Make the chart responsive
            maintainAspectRatio: false // Allow the chart to adjust its aspect ratio
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
    updatePeriodDisplayWithMonth(selectedYear, selectedMonth);
    updateChart(selectedYear, selectedMonth);
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
    updatePeriodDisplayWithMonth(selectedYear, selectedMonth);
    updateChart(selectedYear, selectedMonth);
}

function switchToNextYear() {
    if (selectedYear === finalYear) {
        updateWarnMessage("No More Data");
        return
    }
    else {
        selectedYear = selectedYear + 1
    }
    updatePeriodDisplayWithYear(selectedYear);
    updateChart(selectedYear, selectedMonth, true);
}

function switchToPrevYear() {
    if (selectedYear === firstYear) {
        updateWarnMessage("No More Data");
        return
    }
    else {
        selectedYear = selectedYear - 1;
    }
    updatePeriodDisplayWithYear(selectedYear);
    updateChart(selectedYear, selectedMonth, true);
}

function toggleSummaryPeriod() {
    document.getElementById('prev-button').replaceWith(document.getElementById('prev-button').cloneNode(true));
    document.getElementById('next-button').replaceWith(document.getElementById('next-button').cloneNode(true));

    if (summaryPeriod === "monthly") {
        document.getElementById('prev-button').addEventListener('click', () => switchToPrevYear());
        document.getElementById('next-button').addEventListener('click', () => switchToNextYear());

        summaryPeriod = "yearly"
        document.getElementById('period-button').innerText = "Monthly Summary"

        updatePeriodDisplayWithYear(selectedYear);
        updateChart(selectedYear, selectedMonth, true);
    }
    else {
        document.getElementById('prev-button').addEventListener('click', () => switchToPrevMonth());
        document.getElementById('next-button').addEventListener('click', () => switchToNextMonth());

        summaryPeriod = "monthly"
        document.getElementById('period-button').innerText = "Yearly Summary"

        updatePeriodDisplayWithMonth(selectedYear, selectedMonth);
        updateChart(selectedYear, selectedMonth);
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

    // Initialize the chart with the first year in the table
    const firstDate = new Date(gamingData[1].date);
    const lastDate = new Date(gamingData[gamingData.length - 1].date);
    firstYear = parseInt(lastDate.getFullYear())
    firstMonth = parseInt(lastDate.getMonth())
    finalYear = parseInt(firstDate.getFullYear());
    finalMonth = parseInt(firstDate.getMonth());
    
    selectedYear = finalYear
    selectedMonth = finalMonth 

    updatePeriodDisplayWithMonth(selectedYear, selectedMonth);
    updateChart(selectedYear, selectedMonth);
}

document.getElementById('prev-button').addEventListener('click', () => switchToPrevMonth());
document.getElementById('next-button').addEventListener('click', () => switchToNextMonth());

document.getElementById('period-button').addEventListener('click', () => toggleSummaryPeriod());

loadDataFromTable();
