(function(){
  const achInputs = document.querySelectorAll('input.ach');
  const rateInputs = document.querySelectorAll('input.rate');

  function calc(){
    // targets
    let t = 0;
    achInputs.forEach(inp=>{
      const v = Math.max(0, Math.min(100, parseFloat(inp.value || 0)));
      t += (v/100) * 10.0; // 10 per row
    });
    // performance
    let p = 0;
    const rows = ["punctuality","quality","productivity","communication","problemsolving","compliance"];
    rows.forEach(k=>{
      const r = document.querySelector(`input[name="p_${k}"]:checked`);
      const val = r ? parseInt(r.value) : 0;
      p += (val/5.0) * 10.0; // 10 per item
    });
    const total = Math.round((t+p)*100)/100;
    let band = "Needs Improvement";
    if(total >= 90) band = "Excellent";
    else if(total >= 80) band = "Good";
    else if(total >= 70) band = "Satisfactory";

    document.getElementById('sumTargets').textContent = t.toFixed(2);
    document.getElementById('sumPerf').textContent = p.toFixed(2);
    document.getElementById('sumTotal').textContent = total.toFixed(2);
    document.getElementById('sumBand').textContent = band;
  }

  achInputs.forEach(i => i.addEventListener('input', calc));
  rateInputs.forEach(i => i.addEventListener('change', calc));
  calc(); // initial
})();
