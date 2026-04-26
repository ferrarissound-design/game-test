const GAME_SECONDS = 30;
const TARGET_LIFE_MS = 1400;
const INITIAL_WINDOW_MS = 3000;
const COMBO_WINDOW_MS = 2000;

const ui = {
  scenes: {
    title: document.getElementById('scene-title'),
    play: document.getElementById('scene-play'),
    result: document.getElementById('scene-result')
  },
  startBtn: document.getElementById('start-btn'),
  retryBtn: document.getElementById('retry-btn'),
  soundBtn: document.getElementById('sound-btn'),
  score: document.getElementById('score'),
  timer: document.getElementById('timer'),
  combo: document.getElementById('combo'),
  playfield: document.getElementById('playfield'),
  resultScore: document.getElementById('result-score'),
  resultBest: document.getElementById('result-best')
};

const state = {
  scene: 'title',
  score: 0,
  best: Number(localStorage.getItem('bestScore') || 0),
  timeLeft: GAME_SECONDS,
  combo: 0,
  lastHitAt: 0,
  soundOn: true,
  spawnedAt: 0,
  gameInterval: null,
  targetInterval: null,
  targetCount: 1
};

function showScene(sceneName) {
  state.scene = sceneName;
  Object.entries(ui.scenes).forEach(([name, node]) => {
    node.classList.toggle('active', name === sceneName);
  });
}

function randomIn(min, max) {
  return Math.random() * (max - min) + min;
}

function clearTargets() {
  ui.playfield.innerHTML = '';
}

function setTargetCount() {
  const elapsed = GAME_SECONDS - state.timeLeft;
  if (elapsed < 10) {
    state.targetCount = 1;
  } else if (elapsed < 20) {
    state.targetCount = 2;
  } else {
    state.targetCount = 3;
  }
}

function spawnTargets() {
  clearTargets();
  setTargetCount();

  const easyMode = Date.now() - state.spawnedAt < INITIAL_WINDOW_MS;

  for (let i = 0; i < state.targetCount; i += 1) {
    const target = document.createElement('button');
    target.className = 'target';
    target.setAttribute('aria-label', 'わっか');

    const size = easyMode ? randomIn(95, 120) : randomIn(72, 110);
    const x = randomIn(14, 86);
    const y = randomIn(16, 84);

    target.style.width = `${size}px`;
    target.style.height = `${size}px`;
    target.style.left = `${x}%`;
    target.style.top = `${y}%`;

    target.addEventListener('pointerdown', onTargetHit, { once: true });
    ui.playfield.appendChild(target);
  }
}

function calcHitScore() {
  const multiplier = 1 + Math.min(state.combo, 10) * 0.1;
  return Math.round(10 * multiplier);
}

function playBeep() {
  if (!state.soundOn) {
    return;
  }

  const AudioContextClass = window.AudioContext || window.webkitAudioContext;
  if (!AudioContextClass) {
    return;
  }

  const ctx = new AudioContextClass();
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();

  osc.type = 'triangle';
  osc.frequency.value = randomIn(620, 760);
  gain.gain.value = 0.04;

  osc.connect(gain);
  gain.connect(ctx.destination);

  osc.start();
  osc.stop(ctx.currentTime + 0.07);
  osc.onended = () => ctx.close();
}

function onTargetHit(event) {
  const now = Date.now();
  if (now - state.lastHitAt <= COMBO_WINDOW_MS) {
    state.combo += 1;
  } else {
    state.combo = 1;
  }

  const earned = calcHitScore();
  state.score += earned;
  state.lastHitAt = now;

  const target = event.currentTarget;
  target.classList.add('hit');

  ui.combo.textContent = `${state.combo} COMBO! +${earned}`;
  renderHud();
  playBeep();

  setTimeout(() => {
    if (state.scene === 'playing') {
      spawnTargets();
    }
  }, 170);
}

function renderHud() {
  ui.score.textContent = `Score: ${state.score}`;
  ui.timer.textContent = `Time: ${state.timeLeft}`;
}

function endGame() {
  clearInterval(state.gameInterval);
  clearInterval(state.targetInterval);
  state.gameInterval = null;
  state.targetInterval = null;

  clearTargets();

  if (state.score > state.best) {
    state.best = state.score;
    localStorage.setItem('bestScore', String(state.best));
  }

  ui.resultScore.textContent = `SCORE: ${state.score}`;
  ui.resultBest.textContent = `BEST: ${state.best}`;
  ui.combo.textContent = '';

  showScene('result');
}

function tick() {
  state.timeLeft -= 1;
  if (state.timeLeft <= 0) {
    state.timeLeft = 0;
    renderHud();
    endGame();
    return;
  }

  if (Date.now() - state.lastHitAt > COMBO_WINDOW_MS) {
    state.combo = 0;
    ui.combo.textContent = '';
  }

  renderHud();
}

function startGame() {
  state.score = 0;
  state.timeLeft = GAME_SECONDS;
  state.combo = 0;
  state.lastHitAt = 0;
  state.spawnedAt = Date.now();

  showScene('play');
  ui.combo.textContent = '';
  renderHud();
  spawnTargets();

  clearInterval(state.gameInterval);
  clearInterval(state.targetInterval);

  state.gameInterval = setInterval(tick, 1000);
  state.targetInterval = setInterval(() => {
    if (state.scene === 'playing') {
      spawnTargets();
    }
  }, TARGET_LIFE_MS);
}

function toggleSound() {
  state.soundOn = !state.soundOn;
  ui.soundBtn.textContent = state.soundOn ? '🔊 音ON' : '🔇 音OFF';
  ui.soundBtn.setAttribute('aria-pressed', String(state.soundOn));
}

ui.startBtn.addEventListener('click', startGame);
ui.retryBtn.addEventListener('click', startGame);
ui.soundBtn.addEventListener('click', toggleSound);

showScene('title');
ui.resultBest.textContent = `BEST: ${state.best}`;
