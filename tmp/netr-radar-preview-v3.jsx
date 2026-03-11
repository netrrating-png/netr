import { useState, useEffect } from "react";

const fontLink = document.createElement("link");
fontLink.rel = "stylesheet";
fontLink.href = "https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@700;800;900&family=DM+Sans:wght@300;400;500;600&display=swap";
document.head.appendChild(fontLink);

const T = {
  bg:      "#040406",
  card:    "#0A0A0D",
  inner:   "#0F0F14",
  border:  "#1C1C24",
  accent:  "#39FF14",
  blue:    "#4A9EFF",
  gold:    "#F5C542",
  red:     "#FF4545",
  text:    "#EEEEF5",
  sub:     "#6A6A82",
  muted:   "#2E2E3A",
};

// Your actual test answers from the chat session
// Your actual test answers — mix of strengths and weaknesses
const MY_ANSWERS = {
  1: 2, // shooting: about 50/50 → 3.0
  2: 2, // finishing: not consistent → 2.5
  3: 0, // handles: anytime → 5.0  ← strength
  4: 0, // passing: always looking → 5.0  ← strength
  5: 2, // defense: depends → 3.0
  6: 3, // rebounding: bigger guys → 1.5  ← weak
  7: 2, // iq: not instinctive → 2.5
};

const SKILL_QUESTIONS = [
  { id:1, label:"Scoring",   icon:"🎯", scores:[5,4,3,2,2.5] },
  { id:2, label:"Finishing", icon:"🤙", scores:[5,3.5,2.5,1.5,1] },
  { id:3, label:"Handles",   icon:"⚡", scores:[5,4,2.5,1.5,2] },
  { id:4, label:"Passing",   icon:"🔑", scores:[5,3.5,2.5,2,2.5] },
  { id:5, label:"Defense",   icon:"🛡️", scores:[5,4,3,2,1] },
  { id:6, label:"Boards",    icon:"💪", scores:[5,3.5,2.5,1.5,1] },
  { id:7, label:"IQ",        icon:"🧠", scores:[5,3.5,2.5,1.5,1] },
];

function buildSkills(answers) {
  return SKILL_QUESTIONS.map(q => {
    const ai = answers[q.id];
    const raw = ai !== undefined ? q.scores[ai] : 2.5;
    return { ...q, raw, value: (raw - 1) / 4 };
  });
}

function skillColor(value) {
  if (value >= 0.75) return T.accent;
  if (value >= 0.50) return T.blue;
  if (value >= 0.30) return T.gold;
  return T.red;
}

function polygonPoint(cx, cy, radius, sides, index) {
  const angle = (2 * Math.PI * index / sides) - (Math.PI / 2);
  return {
    x: cx + radius * Math.cos(angle),
    y: cy + radius * Math.sin(angle),
  };
}

function RadarChart({ answers, size = 300, animated = true }) {
  const [progress, setProgress] = useState(animated ? 0 : 1);
  const [labelOpacity, setLabelOpacity] = useState(animated ? 0 : 1);
  const skills = buildSkills(answers);
  const n = skills.length;
  const cx = size / 2;
  const cy = size / 2;
  const maxR = size / 2 * 0.60;
  const labelR = size / 2 * 0.90;
  const levels = 5;

  useEffect(() => {
    if (!animated) return;
    let start = null;
    const duration = 900;
    const anim = (ts) => {
      if (!start) start = ts;
      const p = Math.min((ts - start) / duration, 1);
      // ease out cubic
      setProgress(1 - Math.pow(1 - p, 3));
      if (p < 1) requestAnimationFrame(anim);
    };
    const t = setTimeout(() => requestAnimationFrame(anim), 150);
    const lt = setTimeout(() => setLabelOpacity(1), 900);
    return () => { clearTimeout(t); clearTimeout(lt); };
  }, []);

  // Build ring polygon points
  function ringPath(fraction) {
    return skills.map((_, i) => {
      const pt = polygonPoint(cx, cy, maxR * fraction, n, i);
      return `${pt.x},${pt.y}`;
    }).join(" ");
  }

  // Build skill polygon (animated)
  // Visual floor: lowest skill shows at 28% of max radius
  // so the shape never collapses into a blob — scores still shown as numbers
  const VISUAL_FLOOR = 0.28;
  function skillPath() {
    return skills.map((s, i) => {
      const raw = s.value * progress;
      // Map 0–1 score into VISUAL_FLOOR–1.0 display range
      const v = VISUAL_FLOOR + (1 - VISUAL_FLOOR) * raw;
      const pt = polygonPoint(cx, cy, maxR * v, n, i);
      return `${pt.x},${pt.y}`;
    }).join(" ");
  }

  return (
    <svg width={size} height={size} style={{ overflow: "visible" }}>
      {/* Background rings */}
      {Array.from({ length: levels }, (_, li) => {
        const frac = (li + 1) / levels;
        const isOuter = li === levels - 1;
        return (
          <polygon
            key={li}
            points={ringPath(frac)}
            fill={isOuter ? `${T.accent}12` : "none"}
            stroke={isOuter ? `${T.accent}30` : `${T.muted}80`}
            strokeWidth={isOuter ? 1 : 0.5}
          />
        );
      })}

      {/* Spokes */}
      {skills.map((_, i) => {
        const pt = polygonPoint(cx, cy, maxR, n, i);
        return (
          <line key={i}
            x1={cx} y1={cy} x2={pt.x} y2={pt.y}
            stroke={T.muted} strokeWidth={0.5} opacity={0.8}
          />
        );
      })}

      {/* Skill polygon — glow layer */}
      <polygon
        points={skillPath()}
        fill={`${T.accent}20`}
        stroke={`${T.accent}55`}
        strokeWidth={6}
        strokeLinejoin="round"
        style={{ filter: `drop-shadow(0 0 8px ${T.accent}88)` }}
      />

      {/* Skill polygon — crisp layer */}
      <polygon
        points={skillPath()}
        fill={`${T.accent}18`}
        stroke={T.accent}
        strokeWidth={1.5}
        strokeLinejoin="round"
      />

      {/* Vertex dots */}
      {skills.map((s, i) => {
        const raw = s.value * progress;
        const v = VISUAL_FLOOR + (1 - VISUAL_FLOOR) * raw;
        const pt = polygonPoint(cx, cy, maxR * v, n, i);
        return (
          <g key={i}>
            <circle cx={pt.x} cy={pt.y} r={5} fill={T.accent} opacity={progress}
              style={{ filter: `drop-shadow(0 0 4px ${T.accent})` }} />
            <circle cx={pt.x} cy={pt.y} r={2.5} fill="#fff" opacity={progress * 0.9} />
          </g>
        );
      })}

      {/* Labels */}
      {skills.map((s, i) => {
        const pt = polygonPoint(cx, cy, labelR, n, i);
        const c = skillColor(s.value);
        const isRight = pt.x > cx + 10;
        const isLeft  = pt.x < cx - 10;
        const anchor  = isRight ? "start" : isLeft ? "end" : "middle";
        return (
          <g key={i} opacity={labelOpacity} style={{ transition: "opacity 0.5s ease" }}>
            <text
              x={pt.x} y={pt.y - 14}
              textAnchor={anchor}
              fontSize={13}
              style={{ fontFamily: "DM Sans" }}
            >{s.icon}</text>
            <text
              x={pt.x} y={pt.y + 2}
              textAnchor={anchor}
              fill={c}
              fontSize={10}
              fontWeight={800}
              letterSpacing="0.8"
              style={{ fontFamily: "'Barlow Condensed', sans-serif", textTransform: "uppercase" }}
            >{s.label}</text>
            <text
              x={pt.x} y={pt.y + 14}
              textAnchor={anchor}
              fill={c}
              fontSize={11}
              fontWeight={700}
              style={{ fontFamily: "'Barlow Condensed', sans-serif" }}
            >{s.raw.toFixed(1)}</text>
          </g>
        );
      })}
    </svg>
  );
}

function LegendDot({ color, label }) {
  return (
    <div style={{ display:"flex", alignItems:"center", gap:5 }}>
      <div style={{ width:7, height:7, borderRadius:"50%", background:color }} />
      <span style={{ fontSize:11, color:T.sub, fontFamily:"'DM Sans'" }}>{label}</span>
      {showInfo && <InfoModal onClose={() => setShowInfo(false)} />}
    </div>
  );
}

function InsightRow({ icon, color, label, items }) {
  if (!items.length) return null;
  return (
    <div style={{ display:"flex", alignItems:"center", gap:10 }}>
      <span style={{ fontSize:14 }}>{icon}</span>
      <span style={{ fontSize:13, color, fontFamily:"'DM Sans'", fontWeight:600, minWidth:68 }}>{label}</span>
      <span style={{ fontSize:13, color:T.text, fontFamily:"'DM Sans'" }}>{items.join(", ")}</span>
      {showInfo && <InfoModal onClose={() => setShowInfo(false)} />}
    </div>
  );
}

function InfoModal({ onClose }) {
  return (
    <div
      onClick={onClose}
      style={{
        position:"fixed", inset:0, background:"rgba(4,4,6,0.88)",
        display:"flex", alignItems:"flex-end", justifyContent:"center",
        zIndex:999, backdropFilter:"blur(6px)",
        animation:"fadeIn .2s ease",
      }}
    >
      <style>{`
        @keyframes fadeIn { from{opacity:0} to{opacity:1} }
        @keyframes slideUp { from{transform:translateY(40px);opacity:0} to{transform:translateY(0);opacity:1} }
      `}</style>
      <div
        onClick={e => e.stopPropagation()}
        style={{
          background:"#0F0F14", borderRadius:"24px 24px 0 0",
          border:"1px solid #1C1C24", borderBottom:"none",
          padding:"28px 24px 48px", width:"100%", maxWidth:480,
          animation:"slideUp .3s ease",
        }}
      >
        <div style={{ width:36, height:4, borderRadius:99, background:"#2E2E3A", margin:"0 auto 24px" }} />

        <div style={{ display:"flex", alignItems:"center", gap:10, marginBottom:20 }}>
          <div style={{
            width:34, height:34, borderRadius:10,
            background:"rgba(57,255,20,0.12)", border:"1px solid rgba(57,255,20,0.3)",
            display:"flex", alignItems:"center", justifyContent:"center", fontSize:16,
          }}>ℹ️</div>
          <div>
            <div style={{ fontFamily:"'Barlow Condensed'", fontWeight:900, fontSize:22, color:"#EEEEF5" }}>
              How Your Score Is Calculated
            </div>
            <div style={{ fontSize:12, color:"#6A6A82", marginTop:1 }}>Self-Assessment Estimate</div>
          </div>
        </div>

        {[
          { icon:"🎯", title:"7 Core Skill Areas", body:"Your answers across Scoring, Finishing, Handles, Passing, Defense, Rebounding, and Basketball IQ are each weighted based on how much they reflect overall player value.", highlight:false },
          { icon:"⚖️", title:"Weighted & Calibrated", body:"Not all categories count equally. Answers are run through a multi-factor model that accounts for level played, age, and consistency across your responses.", highlight:false },
          { icon:"📉", title:"Self-Assessment Discount", body:"Research shows players consistently rate themselves higher than peers do. A built-in discount keeps your estimate realistic — it\'s not a penalty, it\'s calibration.", highlight:false },
          { icon:"🏀", title:"This Is Just the Starting Line", body:"Your true NETR comes from the court. Every game you play, teammates and opponents rate you — those peer ratings move your score up or down over time.", highlight:true },
        ].map((s, i) => (
          <div key={i} style={{
            marginBottom:14, padding:"14px 16px", borderRadius:14,
            background: s.highlight ? "rgba(57,255,20,0.07)" : "rgba(255,255,255,0.03)",
            border: `1px solid ${s.highlight ? "rgba(57,255,20,0.22)" : "#1C1C24"}`,
          }}>
            <div style={{ display:"flex", gap:10, alignItems:"flex-start" }}>
              <span style={{ fontSize:17, flexShrink:0, marginTop:1 }}>{s.icon}</span>
              <div>
                <div style={{ fontFamily:"'Barlow Condensed'", fontWeight:800, fontSize:16, color: s.highlight ? "#39FF14" : "#EEEEF5", marginBottom:4 }}>{s.title}</div>
                <div style={{ fontSize:13, color:"#6A6A82", lineHeight:1.6 }}>{s.body}</div>
              </div>
            </div>
          </div>
        ))}

        <button onClick={onClose} style={{
          width:"100%", padding:"15px", borderRadius:14, marginTop:6,
          background:"linear-gradient(135deg,#39FF14,#00CC2A)",
          border:"none", color:"#040406", fontFamily:"'DM Sans'",
          fontWeight:700, fontSize:15, cursor:"pointer",
        }}>Got it</button>
      </div>
      {showInfo && <InfoModal onClose={() => setShowInfo(false)} />}
    </div>
  );
}

export default function App() {
  const [key] = useState(0);
  const [showInfo, setShowInfo] = useState(false);
  const skills = buildSkills(MY_ANSWERS);

  const strengths  = skills.filter(s => s.value >= 0.70).sort((a,b) => b.value - a.value);
  const weaknesses = skills.filter(s => s.value < 0.45).sort((a,b) => a.value - b.value);

  return (
    <div style={{
      minHeight:"100vh", background:T.bg, display:"flex", flexDirection:"column",
      alignItems:"center", justifyContent:"flex-start", padding:"40px 20px 60px",
      fontFamily:"'DM Sans', sans-serif",
    }}>

      {/* Header */}
      <div style={{ marginBottom:8, display:"flex", alignItems:"center", gap:10 }}>
        <div style={{
          width:36, height:36, borderRadius:10,
          background:`linear-gradient(135deg,${T.accent},#00CC2A)`,
          display:"flex", alignItems:"center", justifyContent:"center",
          boxShadow:`0 0 20px ${T.accent}66`,
        }}>
          <span style={{ fontFamily:"'Barlow Condensed'", fontWeight:900, fontSize:18, color:"#fff" }}>N</span>
        </div>
        <span style={{ fontFamily:"'Barlow Condensed'", fontWeight:900, fontSize:28, color:T.text, letterSpacing:"-0.01em" }}>NETR</span>
      </div>

      <div style={{ fontSize:11, color:T.sub, letterSpacing:"1.8px", textTransform:"uppercase", marginBottom:32 }}>
        Skill Radar Preview
      </div>



      {/* Main card */}
      <div style={{
        background:T.card, borderRadius:24, border:`1px solid ${T.border}`,
        padding:"28px 24px", width:"100%", maxWidth:400,
        display:"flex", flexDirection:"column", alignItems:"center", gap:20,
      }}>

        <div style={{ display:"flex", alignItems:"center", justifyContent:"space-between", width:"100%" }}>
          <div style={{ fontSize:11, color:T.sub, letterSpacing:"1.8px", textTransform:"uppercase", fontFamily:"'DM Sans'" }}>
            Skill Breakdown
          </div>
          <button
            onClick={() => setShowInfo(true)}
            title="How is this calculated?"
            style={{
              width:26, height:26, borderRadius:"50%",
              background:"rgba(106,106,130,0.12)",
              border:"1px solid #2E2E3A",
              display:"flex", alignItems:"center", justifyContent:"center",
              cursor:"pointer", flexShrink:0,
            }}
          >
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none">
              <circle cx="12" cy="12" r="10" stroke="#6A6A82" strokeWidth="1.8"/>
              <path d="M12 11v6" stroke="#6A6A82" strokeWidth="2" strokeLinecap="round"/>
              <circle cx="12" cy="7.5" r="1" fill="#6A6A82"/>
            </svg>
          </button>
        </div>

        {/* Radar chart */}
        <RadarChart key={key} answers={MY_ANSWERS} size={290} animated={true} />

        {/* Legend */}
        <div style={{ display:"flex", gap:12, flexWrap:"wrap", justifyContent:"center" }}>
          <LegendDot color={T.accent} label="Strong" />
          <LegendDot color={T.blue}   label="Solid" />
          <LegendDot color={T.gold}   label="Developing" />
          <LegendDot color={T.red}    label="Focus area" />
        </div>

        {/* Insights */}
        {(strengths.length > 0 || weaknesses.length > 0) && (
          <div style={{
            width:"100%", background:T.inner, borderRadius:14,
            border:`1px solid ${T.border}`, padding:"14px 16px",
            display:"flex", flexDirection:"column", gap:10,
          }}>
            <InsightRow icon="⚡" color={T.accent} label="Strengths"
              items={strengths.slice(0,2).map(s=>s.label)} />
            <InsightRow icon="🎯" color={T.gold} label="Work on"
              items={weaknesses.slice(0,2).map(s=>s.label)} />
          </div>
        )}

        {/* Score row */}
        <div style={{ display:"flex", gap:8, flexWrap:"wrap", justifyContent:"center" }}>
          {skills.map(s => (
            <div key={s.id} style={{
              background:`${skillColor(s.value)}12`,
              border:`1px solid ${skillColor(s.value)}33`,
              borderRadius:10, padding:"8px 10px", textAlign:"center", minWidth:60,
            }}>
              <div style={{ fontSize:14 }}>{s.icon}</div>
              <div style={{
                fontFamily:"'Barlow Condensed'", fontWeight:900, fontSize:16,
                color:skillColor(s.value), lineHeight:1.1,
              }}>{s.raw.toFixed(1)}</div>
              <div style={{ fontSize:10, color:T.sub, marginTop:2, fontWeight:600, letterSpacing:"0.04em" }}>
                {s.label.toUpperCase()}
              </div>
            </div>
          ))}
        </div>

      </div>


      {showInfo && <InfoModal onClose={() => setShowInfo(false)} />}
    </div>
  );
}
