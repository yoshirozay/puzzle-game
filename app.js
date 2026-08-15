/**
 * Tiki Lounge landing — hanging-sign carousel + page wiring.
 * Matches GamePicker hanging boards: wood plank, accent stripe, top-cropped video.
 * Live at https://tiki-lounge.vercel.app/
 */
(function () {
  // ── Config ──────────────────────────────────────────────────
  // Swap this for the real App Store URL when the listing is live.
  const APP_STORE_URL =
    "https://apps.apple.com/search?term=Tiki%20Lounge%20Offline%20Games";

  const GAMES = [
    {
      id: "lounge",
      name: "The Lounge",
      genre: "HOME",
      blurb: "Decorate the bar",
      accent: "#e8b450",
      icon: null,
      video: "assets/previews/preview-lounge.mp4",
      poster: "assets/previews/poster-lounge.png",
      isLounge: true,
      tileCopy: "Spend points on decor. Vic hands out daily rewards.",
    },
    {
      id: "stacks",
      name: "Totem",
      genre: "BLOCK PUZZLE",
      blurb: "Stack blocks. Clear lines.",
      accent: "#e86b4a",
      icon: "assets/icons/totem.svg",
      video: "assets/previews/preview-stacks.mp4",
      poster: "assets/previews/poster-stacks.png",
      tileCopy: "Drop blocks on the board. Clear full lines. The lagoon deepens as you go.",
    },
    {
      id: "luau",
      name: "Luau",
      genre: "MATCH-3",
      blurb: "Match tiles. Chain combos.",
      accent: "#4a8a9a",
      icon: "assets/icons/luau.svg",
      video: "assets/previews/preview-luau.mp4",
      poster: "assets/previews/poster-luau.png",
      tileCopy: "Swap pieces to match three or more. Specials clear big chunks of the board.",
    },
    {
      id: "zombie",
      name: "Top Shelf",
      genre: "MERGE 2048",
      blurb: "Merge drinks up the shelf.",
      accent: "#ee8a54",
      icon: "assets/icons/top-shelf.svg",
      video: "assets/previews/preview-zombie.mp4",
      poster: "assets/previews/poster-zombie.png",
      tileCopy: "Swipe to merge matching cocktails — same idea as 2048, with a tiki bar.",
    },
    {
      id: "cipher",
      name: "Cabana Cipher",
      genre: "LETTER PUZZLE",
      blurb: "Crack letter puzzles.",
      accent: "#f2e4c1",
      icon: "assets/icons/cipher.svg",
      video: "assets/previews/preview-cipher.mp4",
      poster: "assets/previews/poster-cipher.png",
      tileCopy: "Decode secret phrases one letter at a time. Hints from Vic when you’re stuck.",
    },
    {
      id: "blueprints",
      name: "Blueprints",
      genre: "PICTURE GRID",
      blurb: "Fill the grid from the clues.",
      accent: "#6a6990",
      icon: "assets/icons/blueprints.svg",
      video: "assets/previews/preview-blueprints.mp4",
      poster: "assets/previews/poster-blueprints.png",
      tileCopy: "Use the numbers to shade the right cells and reveal each picture.",
    },
    {
      id: "navigator",
      name: "Navigator",
      genre: "MEMORY",
      blurb: "Memorize stars. Chart them back.",
      accent: "#54e8da",
      icon: "assets/icons/navigator.svg",
      video: "assets/previews/preview-navigator.mp4",
      poster: "assets/previews/poster-navigator.png",
      tileCopy: "Watch the star pattern, then tap it from memory. Win and the constellation draws itself.",
    },
  ];

  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // ── App Store links ─────────────────────────────────────────
  document.querySelectorAll("[data-app-store]").forEach((el) => {
    el.setAttribute("href", APP_STORE_URL);
    el.setAttribute("target", "_blank");
    el.setAttribute("rel", "noopener noreferrer");
  });

  const yearEl = document.getElementById("year");
  if (yearEl) yearEl.textContent = String(new Date().getFullYear());

  // ── Build signs ─────────────────────────────────────────────
  const track = document.getElementById("carousel-track");
  const carousel = document.getElementById("carousel");
  const dotsEl = document.getElementById("rail-dots");
  const gridEl = document.getElementById("games-grid");

  if (!track || !carousel) return;

  GAMES.forEach((game, i) => {
    const sign = document.createElement("article");
    sign.className = "sign";
    sign.dataset.index = String(i);
    sign.setAttribute("role", "group");
    sign.setAttribute("aria-roledescription", "slide");
    sign.setAttribute("aria-label", `${i + 1} of ${GAMES.length}: ${game.name}`);

    const iconHtml = game.isLounge
      ? `<div class="sign-icon sign-icon--flame" aria-hidden="true">🔥</div>`
      : `<img class="sign-icon" src="${game.icon}" alt="" width="34" height="34" />`;

    const mediaHtml = game.isLounge
      ? `<div class="lounge-crest" aria-hidden="true">
           <div class="crest-torch">
             <div class="crest-flame"></div>
             <div class="crest-shaft"></div>
           </div>
         </div>
         <video muted loop playsinline preload="none" poster="${game.poster}" data-src="${game.video}"></video>
         <img class="poster" src="${game.poster}" alt="" />`
      : `<img class="poster" src="${game.poster}" alt="" />
         <video muted loop playsinline preload="none" poster="${game.poster}" data-src="${game.video}"></video>`;

    // For lounge, show crest by default; video still available if preferred.
    // User asked for banner flags with preview videos — include lounge video too.
    // Actually for lounge in app it's torch crest not video. But we have lounge.mp4.
    // I'll use video for lounge when focused, with crest as poster-style fallback.
    // Simpler: use video for all including lounge.

    sign.innerHTML = `
      <div class="sign-straps" aria-hidden="true">
        <div class="strap"></div>
        <div class="strap"></div>
      </div>
      <div class="sign-board">
        <div class="sign-plate">
          ${iconHtml}
          <div class="sign-name">${escapeHtml(game.name)}</div>
        </div>
        <div class="sign-stripe" style="background:${game.accent}"></div>
        <div class="sign-window-wrap">
          <div class="sign-window-mat" aria-hidden="true"></div>
          <div class="sign-window">
            <img class="poster" src="${game.poster}" alt="" />
            <video muted loop playsinline preload="none" poster="${game.poster}" data-src="${game.video}"></video>
          </div>
        </div>
        <div class="sign-footer">
          <div>
            <div class="sign-genre">${escapeHtml(game.genre)}</div>
            <div class="sign-blurb">${escapeHtml(game.blurb)}</div>
          </div>
          <div class="play-pill">Play</div>
        </div>
      </div>
    `;
    track.appendChild(sign);

    // Dot
    const dot = document.createElement("button");
    dot.type = "button";
    dot.className = "rail-dot";
    dot.setAttribute("role", "tab");
    dot.setAttribute("aria-label", game.name);
    dot.setAttribute("aria-selected", i === 0 ? "true" : "false");
    dot.dataset.index = String(i);
    dotsEl.appendChild(dot);
  });

  // Games grid — jumps the marquee to that board, then resumes auto-scroll
  GAMES.filter((g) => !g.isLounge).forEach((game) => {
    const tile = document.createElement("button");
    tile.type = "button";
    tile.className = "game-tile";
    tile.style.setProperty("--tile-accent", game.accent);
    tile.innerHTML = `
      <img src="${game.icon}" alt="" width="52" height="52" />
      <div>
        <h3>${escapeHtml(game.name)}</h3>
        <p>${escapeHtml(game.tileCopy)}</p>
        <span class="genre">${escapeHtml(game.genre)}</span>
      </div>
    `;
    tile.addEventListener("click", () => {
      const idx = GAMES.findIndex((g) => g.id === game.id);
      if (idx >= 0) {
        jumpTo(idx);
        document.getElementById("games")?.scrollIntoView({
          behavior: reduceMotion ? "auto" : "smooth",
        });
      }
    });
    gridEl?.appendChild(tile);
  });

  function escapeHtml(s) {
    return s
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  // ── Infinite auto-marquee ───────────────────────────────────
  // Continuous leftward scroll. Cards are cloned twice (3 full sets) so
  // the seam never sits near the visible window. Videos stay loaded —
  // never torn down on wrap (that caused the "front three vanish" glitch).
  const COUNT = GAMES.length;
  const SETS = 3; // original + 2 clones

  function cloneSignSet() {
    // Always clone the first COUNT nodes (the original set)
    const source = Array.from(track.querySelectorAll(".sign")).slice(0, COUNT);
    source.forEach((node) => {
      const clone = node.cloneNode(true);
      clone.setAttribute("aria-hidden", "true");
      clone.classList.add("sign--clone");
      clone.querySelectorAll("video").forEach((v) => {
        // Keep data-src; clear live src so we assign cleanly below
        v.removeAttribute("src");
        v.classList.remove("is-ready");
      });
      track.appendChild(clone);
    });
  }
  // Build two extra sets (we already have set 0 from the build loop)
  cloneSignSet();
  cloneSignSet();

  let signs = Array.from(track.querySelectorAll(".sign"));
  const dots = Array.from(dotsEl.querySelectorAll(".rail-dot"));
  dots.forEach((d) => {
    d.disabled = true;
    d.tabIndex = -1;
    d.setAttribute("aria-disabled", "true");
  });

  let index = 1;
  let cardStep = 0;
  let cardW = 0;
  let setWidth = 0;
  let padLeft = 0;
  let viewW = 0;
  // Scroll in the middle set so wrap is invisible on both sides
  let offset = 0;
  let lastTick = performance.now();
  let lastVideoSync = 0;
  let pageVisible = !document.hidden;
  let inView = true;
  let focusEl = null; // stable focused DOM node (avoids clone thrash on wrap)
  const loadedVideos = new WeakSet();

  const SPEED_PX = () => Math.max(24, cardStep * 0.31);

  /**
   * Pixel distance of one full game set. Measured with the track transform
   * zeroed so layout positions are absolute and consistent — a wrong
   * setWidth is what makes Lounge (index 0) jump when the loop wraps.
   */
  function measureSetWidth() {
    if (signs.length < COUNT * 2) return cardStep * COUNT;
    const prev = track.style.transform;
    track.style.transform = "translate3d(0,0,0)";
    // Force layout
    void track.offsetWidth;
    // Average across both set boundaries for subpixel stability
    const a0 = signs[0].getBoundingClientRect().left;
    const a1 = signs[COUNT].getBoundingClientRect().left;
    const a2 = signs[COUNT * 2]
      ? signs[COUNT * 2].getBoundingClientRect().left
      : a1 + (a1 - a0);
    track.style.transform = prev;
    const w1 = a1 - a0;
    const w2 = a2 - a1;
    // Prefer the average; fall back if something measured zero
    const avg = (w1 + w2) / 2;
    return avg > 1 ? avg : cardStep * COUNT;
  }

  function measure() {
    signs = Array.from(track.querySelectorAll(".sign"));
    const card = signs[0];
    if (!card) return;
    const style = getComputedStyle(track);
    const gap = parseFloat(style.columnGap || style.gap) || 20;
    cardW = card.offsetWidth || card.getBoundingClientRect().width;
    cardStep = cardW + gap;
    setWidth = measureSetWidth();

    viewW = carousel.getBoundingClientRect().width || window.innerWidth;
    padLeft = Math.max(0, (viewW - cardW) / 2);
    track.style.paddingLeft = "0px";
    track.style.paddingRight = "0px";
    applyTransform();
    syncFocus(true);
  }

  function applyTransform() {
    track.style.transition = "none";
    // Round to device pixels to avoid subpixel shimmer on wrap
    const x = Math.round((padLeft - offset) * 100) / 100;
    track.style.transform = `translate3d(${x}px, 0, 0)`;
  }

  /**
   * Keep offset inside the middle set [setWidth, 2*setWidth).
   * Subtract/add exactly one measured setWidth so the seam is invisible.
   */
  function wrapOffset() {
    if (setWidth <= 0) return;
    // Hysteresis: only wrap when clearly past the boundary (avoids
    // thrashing at the seam when Lounge is centered).
    const hi = setWidth * 2;
    const lo = setWidth;
    if (offset >= hi) {
      offset -= setWidth;
    } else if (offset < lo) {
      offset += setWidth;
    }
  }

  function jumpTo(i) {
    const target = ((i % COUNT) + COUNT) % COUNT;
    // Center that card inside the middle copy using measured spacing
    offset = setWidth + target * (setWidth / COUNT);
    // Prefer exact middle-set card position when available
    if (signs[COUNT + target] && signs[COUNT]) {
      const prev = track.style.transform;
      track.style.transform = "translate3d(0,0,0)";
      void track.offsetWidth;
      const base = signs[COUNT].getBoundingClientRect().left;
      const cardLeft = signs[COUNT + target].getBoundingClientRect().left;
      track.style.transform = prev;
      offset = setWidth + (cardLeft - base);
    }
    wrapOffset();
    applyTransform();
    syncFocus(true);
  }

  function ensureVideoSrc(video) {
    const src = video.dataset.src;
    if (!src) return;
    if (video.getAttribute("src") === src) return;
    video.src = src;
    video.load();
    loadedVideos.add(video);
    video.addEventListener(
      "loadeddata",
      () => {
        // Mark ready for every clone so wrap never fades poster→video
        video.classList.add("is-ready");
        const sign = video.closest(".sign");
        if (sign?.classList.contains("is-focus")) {
          video.play().catch(() => {});
        }
      },
      { once: true }
    );
  }

  function syncFocus(forceVideos) {
    const carRect = carousel.getBoundingClientRect();
    const centerX = carRect.left + carRect.width / 2;
    let bestEl = null;
    let bestDist = Infinity;
    for (const el of signs) {
      const r = el.getBoundingClientRect();
      if (r.right < carRect.left - cardW || r.left > carRect.right + cardW) continue;
      const cx = r.left + r.width / 2;
      const d = Math.abs(cx - centerX);
      if (d < bestDist) {
        bestDist = d;
        bestEl = el;
      }
    }
    if (!bestEl) return;

    const next = Number(bestEl.dataset.index) || 0;
    const indexChanged = next !== index;
    const cloneSwap =
      !indexChanged && focusEl && focusEl !== bestEl && focusEl.isConnected;

    index = next;

    // Wrap often swaps which clone of Lounge (index 0) is centered. Moving
    // is-focus between clones re-triggers the scale animation → visible jump.
    // For same-index swaps, transfer focus with transitions disabled.
    if (cloneSwap) {
      const oldVideo = focusEl.querySelector("video");
      const newVideo = bestEl.querySelector("video");
      // Hand off playback time so the loop doesn't restart mid-clip
      if (oldVideo && newVideo && oldVideo.readyState >= 2) {
        try {
          newVideo.currentTime = oldVideo.currentTime;
        } catch (_) {}
        newVideo.classList.add("is-ready");
      }
      signs.forEach((el) => {
        el.style.transition = "none";
      });
      signs.forEach((el) => {
        el.classList.toggle("is-focus", el === bestEl);
      });
      // Flush styles so the next frame re-enables transitions cleanly
      void track.offsetWidth;
      signs.forEach((el) => {
        el.style.transition = "";
      });
    } else {
      signs.forEach((el) => {
        el.classList.toggle("is-focus", el === bestEl);
      });
    }

    focusEl = bestEl;

    dots.forEach((d, i) => {
      d.setAttribute("aria-selected", i === index ? "true" : "false");
    });

    const now = performance.now();
    if (forceVideos || indexChanged || cloneSwap || now - lastVideoSync > 280) {
      lastVideoSync = now;
      manageVideos(bestEl, carRect);
    }
  }

  function manageVideos(focusElNow, carRect) {
    const centerX = carRect.left + carRect.width / 2;
    signs.forEach((sign) => {
      const video = sign.querySelector("video");
      if (!video) return;
      const r = sign.getBoundingClientRect();
      const cx = r.left + r.width / 2;
      const dist = Math.abs(cx - centerX);
      const near = dist < cardStep * 2.6;
      const isFocus = sign === focusElNow;

      if (reduceMotion) {
        video.pause();
        return;
      }

      if (near) {
        ensureVideoSrc(video);
        if (isFocus) {
          if (video.readyState >= 2) {
            video.classList.add("is-ready");
            video.play().catch(() => {});
          }
        } else {
          video.pause();
          // Stay is-ready once buffered — no poster flash on wrap
        }
      } else {
        video.pause();
      }
    });
  }

  function tick(now) {
    const dt = Math.min(0.05, (now - lastTick) / 1000);
    lastTick = now;

    if (!reduceMotion && pageVisible && inView && setWidth > 0) {
      offset += SPEED_PX() * dt;
      wrapOffset();
      applyTransform();
      syncFocus(false);
    }

    requestAnimationFrame(tick);
  }

  document.addEventListener("visibilitychange", () => {
    pageVisible = !document.hidden;
  });

  if ("IntersectionObserver" in window) {
    const io = new IntersectionObserver(
      (entries) => {
        for (const ent of entries) inView = ent.isIntersecting;
      },
      { threshold: 0.12 }
    );
    io.observe(carousel);
  }

  if (reduceMotion) {
    // jumpTo needs measure first — deferred to init
  }

  // ── Lounge section video autoplay when visible ──────────────
  const loungeVideo = document.getElementById("lounge-video");
  if (loungeVideo && "IntersectionObserver" in window) {
    const io = new IntersectionObserver(
      (entries) => {
        for (const ent of entries) {
          if (ent.isIntersecting && !reduceMotion) {
            loungeVideo.play().catch(() => {});
          } else {
            loungeVideo.pause();
          }
        }
      },
      { threshold: 0.35 }
    );
    io.observe(loungeVideo);
  }

  // ── Scroll reveal ───────────────────────────────────────────
  document
    .querySelectorAll(
      ".section-head, .feature-card, .lounge-section, .nightly-inner, .game-tile, .final-cta-card"
    )
    .forEach((el) => el.classList.add("reveal"));

  if ("IntersectionObserver" in window && !reduceMotion) {
    const rev = new IntersectionObserver(
      (entries) => {
        for (const ent of entries) {
          if (ent.isIntersecting) {
            ent.target.classList.add("is-in");
            rev.unobserve(ent.target);
          }
        }
      },
      { threshold: 0.12, rootMargin: "0px 0px -40px 0px" }
    );
    document.querySelectorAll(".reveal").forEach((el) => rev.observe(el));
  } else {
    document.querySelectorAll(".reveal").forEach((el) => el.classList.add("is-in"));
  }

  // ── Init ────────────────────────────────────────────────────
  measure();
  // Warm every video source once so the loop never hits empty nodes
  signs.forEach((sign) => {
    const video = sign.querySelector("video");
    if (video) ensureVideoSrc(video);
  });
  jumpTo(1);
  lastTick = performance.now();
  if (!reduceMotion) requestAnimationFrame(tick);

  function onViewportChange() {
    const gameFrac =
      setWidth > 0 ? (((offset % setWidth) + setWidth) % setWidth) / setWidth : 0;
    measure();
    offset = setWidth + gameFrac * setWidth;
    wrapOffset();
    applyTransform();
    syncFocus(true);
  }

  window.addEventListener("resize", onViewportChange);
  window.addEventListener("orientationchange", () => {
    // Wait a beat for the browser to settle new layout metrics
    setTimeout(onViewportChange, 120);
  });
  if (window.visualViewport) {
    window.visualViewport.addEventListener("resize", onViewportChange);
  }

  if (document.fonts?.ready) {
    document.fonts.ready.then(() => {
      measure();
      jumpTo(index);
    });
  }
})();
