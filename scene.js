/**
 * Totem lagoon backdrop — web port of TikiBackgroundView / TikiScene.
 * Flat-color bands, slow 90s dusk breath, drifting clouds, wavelets, palms.
 * Live at https://tiki-lounge.vercel.app/
 */
(function () {
  const canvas = document.getElementById("lagoon");
  if (!canvas) return;
  const ctx = canvas.getContext("2d", { alpha: false });

  const P = {
    blossom: [1.0, 0.965, 0.894],
    cream: [0.949, 0.894, 0.757],
    torch: [0.91, 0.706, 0.314],
    sunsetMid: [0.933, 0.541, 0.329],
    coral: [0.91, 0.42, 0.29],
    clay: [0.773, 0.353, 0.235],
    rum: [0.545, 0.228, 0.18],
    ember: [0.29, 0.106, 0.047],
    lagoon: [0.102, 0.353, 0.42],
    deepLeaf: [0.071, 0.243, 0.286],
    palmLeaf: [0.102, 0.29, 0.337],
    driftwood: [0.42, 0.29, 0.18],
    plank: [0.349, 0.224, 0.122],
    shadowBrown: [0.29, 0.18, 0.102],
    woodDark: [0.231, 0.157, 0.094],
    ink: [0.106, 0.086, 0.075],
    twilight: [0.169, 0.165, 0.337],
  };

  function lerp(a, b, u) {
    return a + (b - a) * u;
  }

  function lerpRGB(a, b, u) {
    return [lerp(a[0], b[0], u), lerp(a[1], b[1], u), lerp(a[2], b[2], u)];
  }

  function mix3(day, mid, night, u) {
    if (u < 0.5) return lerpRGB(day, mid, u * 2);
    return lerpRGB(mid, night, (u - 0.5) * 2);
  }

  function css(rgb, a = 1) {
    const r = Math.round(rgb[0] * 255);
    const g = Math.round(rgb[1] * 255);
    const b = Math.round(rgb[2] * 255);
    return a < 1 ? `rgba(${r},${g},${b},${a})` : `rgb(${r},${g},${b})`;
  }

  let w = 0;
  let h = 0;
  let dpr = 1;
  let start = performance.now() / 1000;
  let raf = 0;
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  function resize() {
    dpr = Math.min(window.devicePixelRatio || 1, 2);
    // Visual viewport when available (mobile URL bar) so the sky stays
    // flush to the real top edge while scrolling.
    const vv = window.visualViewport;
    w = Math.round(vv?.width || window.innerWidth);
    h = Math.round(vv?.height || window.innerHeight);
    canvas.width = Math.floor(w * dpr);
    canvas.height = Math.floor(h * dpr);
    canvas.style.width = w + "px";
    canvas.style.height = h + "px";
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  function band(y0, y1, color) {
    ctx.fillStyle = color;
    ctx.fillRect(0, y0, w, y1 - y0);
  }

  function drawCloud(cx, cy, cw, color) {
    const ch = cw * 0.4;
    ctx.fillStyle = color;
    const baseH = ch * 0.38;
    roundRect(cx - cw / 2, cy + ch / 2 - baseH, cw, baseH, baseH / 2);
    ctx.fill();
    const puffs = [
      [0.22, 0.55, 0.3],
      [0.44, 0.42, 0.42],
      [0.67, 0.52, 0.34],
      [0.85, 0.68, 0.22],
    ];
    for (const [px, py, pr] of puffs) {
      const r = ch * pr;
      ctx.beginPath();
      ctx.arc(cx - cw / 2 + cw * px, cy - ch / 2 + ch * py, r, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  function roundRect(x, y, rw, rh, r) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + rw, y, x + rw, y + rh, r);
    ctx.arcTo(x + rw, y + rh, x, y + rh, r);
    ctx.arcTo(x, y + rh, x, y, r);
    ctx.arcTo(x, y, x + rw, y, r);
    ctx.closePath();
  }

  function drawPalm(px, baseY, scale, flip, t, dusk) {
    const leaf = lerpRGB(P.palmLeaf, P.deepLeaf, dusk * 0.5);
    const wood = lerpRGB(P.shadowBrown, P.woodDark, dusk);
    ctx.save();
    ctx.translate(px, baseY);
    if (flip) ctx.scale(-1, 1);
    ctx.scale(scale, scale);

    // Trunk
    ctx.strokeStyle = css(wood);
    ctx.lineWidth = 10;
    ctx.lineCap = "round";
    ctx.beginPath();
    const sway = Math.sin(t * 0.55) * 6;
    ctx.moveTo(0, 0);
    ctx.quadraticCurveTo(8 + sway * 0.3, -80, 4 + sway, -160);
    ctx.stroke();

    // Fronds
    ctx.strokeStyle = css(leaf);
    ctx.lineWidth = 5;
    const fronds = [
      [-70, -40, -20],
      [-40, -70, -10],
      [10, -75, 5],
      [50, -55, 15],
      [75, -25, 25],
    ];
    for (let i = 0; i < fronds.length; i++) {
      const [fx, fy, mid] = fronds[i];
      const fSway = Math.sin(t * 0.9 + i * 0.8) * 4;
      ctx.beginPath();
      ctx.moveTo(4 + sway, -160);
      ctx.quadraticCurveTo(mid + fSway, -160 + fy * 0.5, fx + fSway, -160 + fy);
      ctx.stroke();
      // secondary vein
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.moveTo(4 + sway, -160);
      ctx.quadraticCurveTo(mid * 0.7 + fSway, -155 + fy * 0.45, fx * 0.7 + fSway, -155 + fy * 0.85);
      ctx.stroke();
      ctx.lineWidth = 5;
    }
    ctx.restore();
  }

  function drawTorch(tx, ty, t, phase) {
    const flameH = 28 + Math.sin(t * 8.3 + phase) * 3;
    // shaft
    ctx.fillStyle = css(P.driftwood);
    ctx.fillRect(tx - 4, ty, 8, 36);
    ctx.fillStyle = css(P.ink, 0.65);
    ctx.fillRect(tx - 4, ty + 8, 8, 2);
    ctx.fillRect(tx - 4, ty + 18, 8, 2);
    ctx.fillRect(tx - 4, ty + 28, 8, 2);
    // flame
    const lean = Math.sin(t * 6.1 + phase) * 2;
    ctx.save();
    ctx.translate(tx + lean, ty);
    const grd = ctx.createLinearGradient(0, -flameH, 0, 0);
    grd.addColorStop(0, css(P.blossom));
    grd.addColorStop(0.35, css(P.torch));
    grd.addColorStop(0.7, css(P.coral));
    grd.addColorStop(1, css(P.rum));
    ctx.fillStyle = grd;
    ctx.beginPath();
    ctx.moveTo(0, -flameH);
    ctx.bezierCurveTo(12, -flameH * 0.6, 14, -flameH * 0.2, 0, 0);
    ctx.bezierCurveTo(-14, -flameH * 0.2, -12, -flameH * 0.6, 0, -flameH);
    ctx.fill();
    ctx.restore();
  }

  /**
   * Signature suspicious cat (CatView / TikiScenery) — ink silhouette,
   * torch-gold eyes, swishing tail. Walks the deck; sits under reduce-motion.
   * Local design box ~100×70; feet at y=0.
   */
  function drawCat(cx, cy, scale, facing, t, walking) {
    const s = scale;
    const blinkPhase = t % 6.5;
    const blink = blinkPhase < 0.18 ? 0.12 : 1.0;
    const tailSwish = Math.sin(t * 0.8) * (walking ? 10 : 14);
    const step = walking ? Math.sin(t * 9.5) : 0;
    const bob = walking ? Math.abs(Math.sin(t * 9.5)) * 2.2 * s : 0;

    ctx.save();
    ctx.translate(cx, cy - bob);
    ctx.scale(facing * s, s);

    // Soft contact shadow on the deck
    ctx.fillStyle = "rgba(27,22,19,0.22)";
    ctx.beginPath();
    ctx.ellipse(4, 4, 28, 6, 0, 0, Math.PI * 2);
    ctx.fill();

    // Tail — curves up from the haunch
    ctx.strokeStyle = css(P.ink);
    ctx.lineWidth = 7.5;
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    ctx.beginPath();
    ctx.moveTo(-18, -8);
    const tailTipX = -42 + Math.sin((tailSwish * Math.PI) / 180) * 6;
    const tailTipY = -38 - Math.cos((tailSwish * Math.PI) / 180) * 4;
    ctx.quadraticCurveTo(-48, -6 + tailSwish * 0.15, tailTipX, tailTipY);
    ctx.stroke();

    // Body (haunch → chest wedge, matching BodyShape)
    ctx.fillStyle = css(P.ink);
    ctx.beginPath();
    ctx.moveTo(-22, -18);
    ctx.lineTo(22, -28);
    ctx.lineTo(28, 0);
    ctx.lineTo(-26, 0);
    ctx.closePath();
    ctx.fill();

    // Legs — step cycle when walking; tucked sit stubs when still
    ctx.lineWidth = 5.5;
    if (walking) {
      // fore
      ctx.beginPath();
      ctx.moveTo(14, -4);
      ctx.lineTo(14 + step * 5, 2);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(8, -4);
      ctx.lineTo(8 - step * 5, 2);
      ctx.stroke();
      // hind
      ctx.beginPath();
      ctx.moveTo(-10, -4);
      ctx.lineTo(-10 - step * 5, 2);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(-16, -4);
      ctx.lineTo(-16 + step * 5, 2);
      ctx.stroke();
    } else {
      ctx.beginPath();
      ctx.moveTo(12, -2);
      ctx.lineTo(12, 2);
      ctx.moveTo(6, -2);
      ctx.lineTo(6, 2);
      ctx.moveTo(-8, -2);
      ctx.lineTo(-8, 2);
      ctx.moveTo(-14, -2);
      ctx.lineTo(-14, 2);
      ctx.stroke();
    }

    // Head
    ctx.beginPath();
    ctx.arc(18, -36, 14, 0, Math.PI * 2);
    ctx.fill();

    // Ears
    ctx.beginPath();
    ctx.moveTo(8, -42);
    ctx.lineTo(12, -56);
    ctx.lineTo(18, -44);
    ctx.closePath();
    ctx.fill();
    ctx.beginPath();
    ctx.moveTo(18, -44);
    ctx.lineTo(26, -56);
    ctx.lineTo(28, -42);
    ctx.closePath();
    ctx.fill();

    // Torch eyes (blink)
    const eyeH = 5 * blink;
    if (eyeH > 0.5) {
      ctx.fillStyle = css(P.torch);
      ctx.beginPath();
      ctx.ellipse(13, -36, 3.6, eyeH * 0.55, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      ctx.ellipse(23, -36, 3.6, eyeH * 0.55, 0, 0, Math.PI * 2);
      ctx.fill();
      // slit pupils
      if (blink > 0.5) {
        ctx.fillStyle = css(P.ink);
        ctx.fillRect(12.4, -37.5, 1.3, 3);
        ctx.fillRect(22.4, -37.5, 1.3, 3);
      }
    }

    ctx.restore();
  }

  /** Pace the deck: walk → short sit → reverse. Period ≈ 18 s each way. */
  function catDeckPose(t, deckTopY, width, height) {
    const walkDur = 11; // seconds to cross
    const sitDur = 3.2; // pause at each end (game-faithful sit)
    const half = walkDur + sitDur;
    const cycle = half * 2;
    const u = ((reduceMotion ? 0 : t) % cycle + cycle) % cycle;
    const margin = 48;
    const y = deckTopY + height * 0.055;
    const scale = Math.min(width, height) / 920;

    if (reduceMotion) {
      return { x: width * 0.68, y, facing: 1, walking: false, scale };
    }

    if (u < walkDur) {
      // left → right
      const p = u / walkDur;
      const ease = p * p * (3 - 2 * p);
      return {
        x: margin + ease * (width - margin * 2),
        y,
        facing: 1,
        walking: true,
        scale,
      };
    }
    if (u < half) {
      // sit at right
      return { x: width - margin, y, facing: -1, walking: false, scale };
    }
    if (u < half + walkDur) {
      // right → left
      const p = (u - half) / walkDur;
      const ease = p * p * (3 - 2 * p);
      return {
        x: width - margin - ease * (width - margin * 2),
        y,
        facing: -1,
        walking: true,
        scale,
      };
    }
    // sit at left
    return { x: margin, y, facing: 1, walking: false, scale };
  }

  function frame(now) {
    const t = reduceMotion ? 0 : now / 1000 - start;
    // depth stays at golden-hour-leaning for the marketing page
    const depth = 0.15;
    const breath = (1 - Math.cos(t * 2 * Math.PI / 90)) / 2;
    const dusk = depth * 0.7 + breath * (1 - depth * 0.7);

    const horizonY = h * 0.58;
    const deckTopY = h * 0.8;

    // Sky bands (mix3 day → mid → night by dusk)
    const bands = [
      [0, h * 0.2, mix3(lerpRGB(P.blossom, P.coral, 0.25), P.coral, P.twilight, dusk)],
      [h * 0.2, h * 0.34, mix3(P.torch, P.sunsetMid, P.rum, dusk)],
      [h * 0.34, h * 0.47, mix3(P.sunsetMid, P.coral, P.ember, dusk)],
      [h * 0.47, horizonY, mix3(P.coral, P.clay, P.clay, dusk)],
    ];
    for (const [y0, y1, c] of bands) band(y0, y1, css(c));

    // Stars (fade in as dusk deepens)
    const starReveal = Math.max(0, (dusk - 0.4) / 0.6);
    if (starReveal > 0) {
      for (let i = 0; i < 28; i++) {
        const px = Math.abs(Math.sin(i * 127.1) * 43758.5453) % 1;
        const py = Math.abs(Math.sin(i * 311.7) * 26951.2917) % 1;
        const twinkle = 0.55 + 0.45 * Math.sin(t * (1.2 + px) + i * 2.3);
        const alpha = starReveal * twinkle * (reduceMotion ? 0.7 : 1);
        const r = i % 5 === 0 ? 1.6 : 1.0;
        ctx.fillStyle = css(P.blossom, alpha);
        ctx.beginPath();
        ctx.arc(px * w, py * h * 0.19, r, 0, Math.PI * 2);
        ctx.fill();
      }
    }

    // Clouds
    const cloudTint = lerpRGB(P.blossom, P.clay, dusk * 0.55);
    const clouds = [
      [5.5, 150, h * 0.065, 0],
      [8.0, 100, h * 0.15, 1],
      [11.0, 120, h * 0.26, 2],
    ];
    for (const [speed, cw, cy, fi] of clouds) {
      const span = w + cw * 2;
      const x = ((t * speed + fi * 520) % span) - cw;
      drawCloud(x, cy, cw, css(cloudTint, 0.92));
    }

    // Sun — bias right so hero copy (left column) sits on coral sky,
    // not the bright disc. Still a presence; the neon sign nests in its glow.
    const sink = dusk * h * 0.05;
    const sunX = w * (w < 720 ? 0.62 : 0.72);
    const sunY = horizonY - h * 0.085 + sink;
    const sunR = w * (w < 720 ? 0.09 : 0.075);
    const disc = lerpRGB(P.blossom, P.torch, dusk);
    const pulse = 1 + 0.015 * Math.sin(t * 0.35);
    ctx.fillStyle = css(disc, 0.25);
    ctx.beginPath();
    ctx.arc(sunX, sunY, sunR * 1.5 * pulse, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = css(disc, 0.35);
    ctx.beginPath();
    ctx.arc(sunX, sunY, sunR * 1.2 * pulse, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = css(disc);
    ctx.beginPath();
    ctx.arc(sunX, sunY, sunR, 0, Math.PI * 2);
    ctx.fill();

    // Island
    const islandC = lerpRGB(P.deepLeaf, P.ink, dusk * 0.6);
    ctx.fillStyle = css(islandC);
    ctx.beginPath();
    const ix = w * 0.84;
    const iy = horizonY;
    const iw = w * 0.18;
    ctx.moveTo(ix - iw, iy);
    ctx.quadraticCurveTo(ix, iy - h * 0.028, ix + iw, iy);
    ctx.closePath();
    ctx.fill();

    // Boat
    const boatX = ((t * 3.2) % (w + 60)) - 30;
    const boatY = horizonY - 8 + Math.sin(t * 0.9) * 1.6;
    ctx.fillStyle = css(lerpRGB(P.ink, P.twilight, dusk * 0.4));
    ctx.beginPath();
    ctx.moveTo(boatX - 14, boatY + 6);
    ctx.lineTo(boatX + 16, boatY + 6);
    ctx.lineTo(boatX + 10, boatY + 12);
    ctx.lineTo(boatX - 10, boatY + 12);
    ctx.closePath();
    ctx.fill();
    // mast
    ctx.strokeStyle = css(P.ink);
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(boatX, boatY + 6);
    ctx.lineTo(boatX - 2, boatY - 10);
    ctx.stroke();
    // sail
    ctx.fillStyle = css(lerpRGB(P.cream, P.ink, dusk * 0.3), 0.85);
    ctx.beginPath();
    ctx.moveTo(boatX - 1, boatY - 10);
    ctx.lineTo(boatX + 10, boatY + 2);
    ctx.lineTo(boatX - 1, boatY + 4);
    ctx.closePath();
    ctx.fill();

    // Ocean
    const oceanC = lerpRGB(P.lagoon, P.deepLeaf, dusk);
    band(horizonY, deckTopY, css(oceanC));

    // Wavelets
    ctx.lineWidth = 1.6;
    for (let row = 0; row < 4; row++) {
      const y = horizonY + (deckTopY - horizonY) * (0.2 + 0.2 * row);
      const amp = 2 + 0.7 * row;
      const speed = 0.55 + 0.14 * row;
      ctx.strokeStyle = css(P.cream, 0.18 + 0.04 * row);
      ctx.beginPath();
      for (let x = 0; x <= w; x += 6) {
        const yy = y + amp * Math.sin((x / 85) * Math.PI * 2 + t * speed + row * 1.7);
        if (x === 0) ctx.moveTo(x, yy);
        else ctx.lineTo(x, yy);
      }
      ctx.stroke();
    }

    // Sun glints
    for (let row = 0; row < 7; row++) {
      const gy = horizonY + 8 + row * 10;
      const shimmer = 0.5 + 0.5 * Math.sin(t * 1.9 + row * 1.35);
      const wobble = 8 * Math.sin(t * 0.7 + row);
      const gw = 42 - row * 3 + wobble;
      const sway = 10 * Math.sin(t * 0.4 + row * 2.2);
      const gx = sunX - gw / 2 + sway;
      const alpha = shimmer * 0.55 * (1 - row / 8) * (1 - dusk * 0.4);
      ctx.fillStyle = css(lerpRGB(P.blossom, P.torch, 0.5), alpha);
      roundRect(gx, gy, gw, 3.4, 1.6);
      ctx.fill();
    }

    // Palms
    drawPalm(w * 0.12, deckTopY + 10, Math.min(w, h) / 700, false, t, dusk);
    drawPalm(w * 0.9, deckTopY + 20, Math.min(w, h) / 780, true, t + 2.4, dusk);

    // Deck
    ctx.fillStyle = css(P.ink);
    ctx.fillRect(0, deckTopY, w, 5);
    const deckC = lerpRGB(P.driftwood, P.shadowBrown, dusk);
    band(deckTopY + 5, h, css(deckC));
    // planks
    ctx.strokeStyle = css(lerpRGB(P.plank, P.woodDark, dusk));
    ctx.lineWidth = 1.5;
    for (let i = 1; i < 10; i++) {
      const x = (w * i) / 10;
      ctx.beginPath();
      ctx.moveTo(x, deckTopY + 5);
      ctx.lineTo(x, h);
      ctx.stroke();
    }
    // alternate plank tint
    ctx.fillStyle = css(P.ink, 0.06);
    for (let i = 0; i < 10; i += 2) {
      ctx.fillRect((w * i) / 10, deckTopY + 5, w / 10, h - deckTopY - 5);
    }

    // Torches
    drawTorch(w * 0.27, deckTopY - 40, t, 0);
    drawTorch(w * 0.73, deckTopY - 36, t, 3.1);

    // Signature black cat — walks the plank deck, sits, turns, walks back
    const cat = catDeckPose(t, deckTopY, w, h);
    drawCat(cat.x, cat.y, cat.scale, cat.facing, t, cat.walking);

    // Very light left-side sky tint only (no blurred blob) — keeps type
    // on coral/dusk bands while the sun lives on the right.
    if (w >= 720) {
      const side = ctx.createLinearGradient(0, 0, w * 0.55, 0);
      side.addColorStop(0, "rgba(27,22,19,0.18)");
      side.addColorStop(0.55, "rgba(27,22,19,0.06)");
      side.addColorStop(1, "rgba(27,22,19,0)");
      ctx.fillStyle = side;
      ctx.fillRect(0, 0, w * 0.55, horizonY);
    }

    if (!reduceMotion) raf = requestAnimationFrame(frame);
  }

  resize();
  window.addEventListener("resize", () => {
    resize();
    if (reduceMotion) frame(performance.now());
  });
  // iOS/Safari: address-bar show/hide changes visualViewport without resize
  if (window.visualViewport) {
    window.visualViewport.addEventListener("resize", () => {
      resize();
      if (reduceMotion) frame(performance.now());
    });
  }

  if (reduceMotion) {
    frame(performance.now());
  } else {
    raf = requestAnimationFrame(frame);
  }

  // Pause when tab hidden
  document.addEventListener("visibilitychange", () => {
    if (document.hidden) {
      cancelAnimationFrame(raf);
    } else if (!reduceMotion) {
      start = performance.now() / 1000 - (performance.now() / 1000 - start);
      raf = requestAnimationFrame(frame);
    }
  });
})();
