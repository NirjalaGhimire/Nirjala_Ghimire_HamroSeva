/**
 * Hamro Sewa admin dashboard — charts & micro-interactions
 */
(function () {
  const muted = "#71717a";
  const gridColor = "rgba(255,255,255,0.06)";

  Chart.defaults.color = "#a1a1aa";
  Chart.defaults.borderColor = gridColor;
  Chart.defaults.font.family = '"Inter", system-ui, sans-serif';

  function drawSparklines() {
    document.querySelectorAll("canvas[data-spark]").forEach((canvas) => {
      const kind = canvas.getAttribute("data-spark");
      const colors = {
        green: "#22c55e",
        red: "#f87171",
        yellow: "#eab308",
        blue: "#60a5fa",
      };
      const c = colors[kind] || colors.green;
      const w = Math.max(canvas.parentElement?.clientWidth || 200, 120);
      const h = 36;
      canvas.width = w;
      canvas.height = h;
      const ctx = canvas.getContext("2d");
      const presets = {
        green: [0.45, 0.52, 0.48, 0.62, 0.58, 0.55, 0.68, 0.64, 0.72, 0.7, 0.78, 0.82],
        red: [0.55, 0.48, 0.52, 0.45, 0.5, 0.58, 0.54, 0.62, 0.6, 0.68, 0.72, 0.75],
        yellow: [0.5, 0.55, 0.42, 0.48, 0.52, 0.45, 0.5, 0.55, 0.48, 0.52, 0.58, 0.5],
        blue: [0.4, 0.45, 0.42, 0.5, 0.55, 0.52, 0.6, 0.58, 0.65, 0.7, 0.68, 0.75],
      };
      const data = presets[kind] || presets.green;
      const n = data.length;
      const max = Math.max(...data);
      const min = Math.min(...data);
      const pad = 2;
      const points = data.map((v, i) => {
        const x = pad + (i / (n - 1)) * (w - pad * 2);
        const y = pad + (1 - (v - min) / (max - min || 1)) * (h - pad * 2);
        return { x, y };
      });
      const grad = ctx.createLinearGradient(0, 0, 0, h);
      grad.addColorStop(0, c + "55");
      grad.addColorStop(1, c + "00");
      ctx.beginPath();
      ctx.moveTo(points[0].x, h - pad);
      points.forEach((p) => ctx.lineTo(p.x, p.y));
      ctx.lineTo(points[n - 1].x, h - pad);
      ctx.closePath();
      ctx.fillStyle = grad;
      ctx.fill();
      ctx.beginPath();
      points.forEach((p, i) => (i === 0 ? ctx.moveTo(p.x, p.y) : ctx.lineTo(p.x, p.y)));
      ctx.strokeStyle = c;
      ctx.lineWidth = 2;
      ctx.lineCap = "round";
      ctx.lineJoin = "round";
      ctx.stroke();
    });
  }

  if (document.readyState === "complete") {
    requestAnimationFrame(drawSparklines);
  } else {
    window.addEventListener("load", () => requestAnimationFrame(drawSparklines));
  }
  window.addEventListener("resize", () => requestAnimationFrame(drawSparklines));

  // —— Line chart (dual series) ——
  const lineCtx = document.getElementById("chartLine");
  if (lineCtx) {
    const days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    new Chart(lineCtx, {
      type: "line",
      data: {
        labels: days,
        datasets: [
          {
            label: "Revenue",
            data: [12, 19, 15, 22, 18, 24, 21],
            borderColor: "#22c55e",
            backgroundColor: (ctx) => {
              const g = ctx.chart.ctx.createLinearGradient(0, 0, 0, 260);
              g.addColorStop(0, "rgba(34, 197, 94, 0.25)");
              g.addColorStop(1, "rgba(34, 197, 94, 0)");
              return g;
            },
            fill: true,
            tension: 0.4,
            borderWidth: 2,
            pointRadius: 0,
            pointHoverRadius: 5,
            pointHoverBackgroundColor: "#22c55e",
            pointHoverBorderColor: "#fff",
            pointHoverBorderWidth: 2,
          },
          {
            label: "Orders",
            data: [8, 14, 11, 16, 13, 19, 17],
            borderColor: "#3b82f6",
            backgroundColor: (ctx) => {
              const g = ctx.chart.ctx.createLinearGradient(0, 0, 0, 260);
              g.addColorStop(0, "rgba(59, 130, 246, 0.2)");
              g.addColorStop(1, "rgba(59, 130, 246, 0)");
              return g;
            },
            fill: true,
            tension: 0.4,
            borderWidth: 2,
            pointRadius: 0,
            pointHoverRadius: 5,
            pointHoverBackgroundColor: "#3b82f6",
            pointHoverBorderColor: "#fff",
            pointHoverBorderWidth: 2,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: { mode: "index", intersect: false },
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: "rgba(17, 17, 20, 0.95)",
            borderColor: "rgba(255,255,255,0.1)",
            borderWidth: 1,
            titleColor: "#f4f4f5",
            bodyColor: "#a1a1aa",
            padding: 12,
            cornerRadius: 8,
          },
        },
        scales: {
          x: {
            grid: { color: gridColor },
            ticks: { color: muted, maxRotation: 0 },
          },
          y: {
            beginAtZero: true,
            grid: { color: gridColor },
            ticks: { color: muted },
          },
        },
      },
    });
  }

  // —— Bar chart ——
  const barCtx = document.getElementById("chartBar");
  if (barCtx) {
    new Chart(barCtx, {
      type: "bar",
      data: {
        labels: ["Home", "Auto", "Beauty", "Tech", "Health", "Other"],
        datasets: [
          {
            data: [420, 310, 280, 190, 350, 120],
            backgroundColor: (ctx) => {
              const g = ctx.chart.ctx.createLinearGradient(0, 220, 0, 0);
              g.addColorStop(0, "rgba(234, 179, 8, 0.85)");
              g.addColorStop(0.5, "rgba(239, 68, 68, 0.75)");
              g.addColorStop(1, "rgba(139, 92, 246, 0.9)");
              return g;
            },
            borderRadius: 8,
            borderSkipped: false,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: "rgba(17, 17, 20, 0.95)",
            borderColor: "rgba(255,255,255,0.1)",
            borderWidth: 1,
            cornerRadius: 8,
          },
        },
        scales: {
          x: {
            grid: { display: false },
            ticks: { color: muted },
          },
          y: {
            beginAtZero: true,
            grid: { color: gridColor },
            ticks: { color: muted },
          },
        },
      },
    });
  }

  // —— Donut ——
  const donutCtx = document.getElementById("chartDonut");
  if (donutCtx) {
    new Chart(donutCtx, {
      type: "doughnut",
      data: {
        labels: ["Completed", "In progress", "Pending quote"],
        datasets: [
          {
            data: [45, 32, 23],
            backgroundColor: ["#22c55e", "#3b82f6", "#eab308"],
            borderWidth: 0,
            hoverOffset: 8,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: "68%",
        plugins: {
          legend: {
            position: "bottom",
            labels: {
              color: "#a1a1aa",
              padding: 16,
              usePointStyle: true,
              pointStyle: "circle",
            },
          },
        },
      },
    });
  }

  // —— Fear & Greed style gauge (SVG arc stroke-dashoffset) ——
  const arc = document.getElementById("gaugeArc");
  const pctEl = document.getElementById("gaugePct");
  const statusEl = document.getElementById("gaugeStatus");
  const arcLen = 251.2; // ~ pi * 80 for semicircle
  const targetPct = 68;
  if (arc && pctEl && statusEl) {
    requestAnimationFrame(() => {
      const offset = arcLen * (1 - targetPct / 100);
      arc.style.strokeDashoffset = String(offset);
    });
    let n = 0;
    const tick = setInterval(() => {
      n += 2;
      if (n >= targetPct) {
        clearInterval(tick);
        pctEl.textContent = targetPct + "%";
      } else {
        pctEl.textContent = n + "%";
      }
    }, 18);
    const msgs = {
      low: "Demand cooling — consider promotions.",
      mid: "Balanced activity across regions.",
      high: "Strong demand — capacity watch.",
    };
    statusEl.textContent =
      targetPct < 40 ? msgs.low : targetPct < 60 ? msgs.mid : msgs.high;
  }

  // —— Nav active state (demo) ——
  document.querySelectorAll(".nav-item[data-nav]").forEach((el) => {
    el.addEventListener("click", (e) => {
      e.preventDefault();
      document.querySelectorAll(".nav-item[data-nav].active").forEach((a) => a.classList.remove("active"));
      el.classList.add("active");
    });
  });
})();
