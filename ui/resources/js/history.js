let gamingData = [];
let selectedYear; let selectedMonth;
let firstYear; let firstMonth
let finalYear; let finalMonth
let chart;

$('table')[0].setAttribute('id','data-table');

function updateMonthDisplay(selectedYear, selectedMonth) {
    selectedMonth = selectedMonth + 1
    selectedDate = new Date(`${selectedYear}-${selectedMonth}`)
    document.getElementById('month-display').innerText = selectedDate.toLocaleDateString("en-US",{ year: 'numeric', month: 'long'})
    updateWarnMessage("")
}

function updateWarnMessage(message) {
    document.getElementById('warn-msg').innerText = message
}

function updateChart(selectedYear, selectedMonth) {
    const firstDate = new Date(selectedYear, selectedMonth, 1);
    const lastDate = new Date(selectedYear, selectedMonth + 1, 0);
    
    const labels = [];
    const data = [];
    
    for (let date = new Date(firstDate); date <= lastDate; date.setDate(date.getDate() + 1)) {
        labels.push(date.getDate());
        const gamingEntry = gamingData.find(item => {
            const itemDate = new Date(item.date);
            return itemDate.getFullYear() === selectedYear && itemDate.getMonth() === selectedMonth && itemDate.getDate() === date.getDate();
        });
        data.push(gamingEntry ? gamingEntry.time / 60 : 0); // Convert minutes to hours
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
                data: data,
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
                    max: 8,
                    callback: (value) => value + ' hrs'
                }
            },
            responsive: true, // Make the chart responsive
            maintainAspectRatio: false // Allow the chart to adjust its aspect ratio
        }
    });
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

    updateMonthDisplay(selectedYear, selectedMonth);
    updateChart(selectedYear, selectedMonth);
}

const prevButton = document.getElementById('prev-button');
const nextButton = document.getElementById('next-button');
 
prevButton.addEventListener('click', () => {
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
    updateMonthDisplay(selectedYear, selectedMonth);
    updateChart(selectedYear, selectedMonth);   
});

nextButton.addEventListener('click', () => {
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
    updateMonthDisplay(selectedYear, selectedMonth);
    updateChart(selectedYear, selectedMonth);
});

loadDataFromTable();
