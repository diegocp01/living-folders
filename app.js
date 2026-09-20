// At most two requests run concurrently. Only the newest waiting intent survives.
class IntentRequests {
  constructor(send, limit = 2) {
    this.send = send;
    this.limit = limit;
    this.active = 0;
    this.cache = new Map();
    this.pending = new Map();
    this.queued = null;
  }
  cancelQueued() {
    if (this.queued) {
      this.pending.delete(this.queued.key);
      this.queued.resolve(null);
      this.queued = null;
    }
  }
  get(key) {
    if (this.cache.has(key)) return Promise.resolve(this.cache.get(key));
    if (this.pending.has(key)) return this.pending.get(key);
    this.cancelQueued();
    let resolve, reject;
    const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
    this.pending.set(key, promise);
    const job = { key, resolve, reject };
    if (this.active < this.limit) this.run(job);
    else this.queued = job;
    return promise;
  }
  async run(job) {
    this.active++;
    try {
      const result = await this.send(job.key);
      this.cache.set(job.key, result);
      if (this.cache.size > 64) this.cache.delete(this.cache.keys().next().value);
      job.resolve(result);
    } catch (error) {
      job.reject(error);
    } finally {
      this.active--;
      this.pending.delete(job.key);
      const next = this.queued;
      this.queued = null;
      if (next) this.run(next);
    }
  }
}

const documents = [
  { id: "flight-nrt", name: "Flight to Tokyo.pdf", kind: "PDF", color: "#e45454", modified: "Yesterday", summary: "Round-trip LAX to Tokyo Narita flight confirmation, terminal and booking code.", tags: ["japan", "trip", "airport", "flight"] },
  { id: "hotel-kyoto", name: "Kyoto hotel.pdf", kind: "PDF", color: "#e45454", modified: "Sep 16", summary: "Eight-night hotel reservation in Kyoto with check-in instructions.", tags: ["japan", "trip", "hotel"] },
  { id: "itinerary", name: "Japan itinerary.key", kind: "KEY", color: "#5a83dd", modified: "Sep 14", summary: "Day-by-day Japan plan covering Tokyo, Kyoto, Osaka, and Nara.", tags: ["japan", "trip", "itinerary"] },
  { id: "rail-pass", name: "JR Pass receipt.pdf", kind: "PDF", color: "#e45454", modified: "Sep 11", summary: "Japan Rail Pass receipt, pickup information, and passport requirements.", tags: ["japan", "trip", "train", "airport"] },
  { id: "airport-transfer", name: "Airport transfer.msg", kind: "MSG", color: "#4f8bd0", modified: "Sep 9", summary: "Narita airport pickup confirmation with meeting point and driver phone number.", tags: ["japan", "trip", "airport", "transfer"] },
  { id: "passport-scan", name: "Passport scan.pdf", kind: "PDF", color: "#e45454", modified: "Aug 28", summary: "Secure copy of passport photo page for international travel.", tags: ["japan", "trip", "airport", "identity"] },
  { id: "packing-list", name: "Packing list.txt", kind: "TXT", color: "#7a8895", modified: "Aug 26", summary: "Clothes, adapters, medicine, camera, and gifts to pack for Japan.", tags: ["japan", "trip", "packing"] },
  { id: "tokyo-map", name: "Tokyo food map.url", kind: "URL", color: "#4ca3a3", modified: "Aug 20", summary: "Saved map of ramen, sushi, coffee, and dessert spots in Tokyo.", tags: ["japan", "trip", "food"] },
  { id: "boarding-app", name: "Airline app link.url", kind: "URL", color: "#4ca3a3", modified: "Aug 19", summary: "Direct link to airline check-in and mobile boarding passes.", tags: ["airport", "flight"] },
  { id: "lounge-pass", name: "Lounge pass.pkpass", kind: "PASS", color: "#3e9378", modified: "Aug 18", summary: "Airport lounge access pass for the departure terminal.", tags: ["airport", "flight"] },

  { id: "python-crash", name: "Python crash course.pdf", kind: "PDF", color: "#e45454", modified: "Sep 13", summary: "Beginner Python programming course with syntax, functions, and projects.", tags: ["python", "coding", "tutorial", "reinvention"] },
  { id: "python-notes", name: "Python notes.md", kind: "MD", color: "#596b78", modified: "Sep 12", summary: "Personal notes on Python lists, dictionaries, classes, and testing.", tags: ["python", "coding", "tutorial"] },
  { id: "django", name: "Django tutorial.url", kind: "URL", color: "#4ca3a3", modified: "Sep 10", summary: "Saved step-by-step tutorial for building a web app with Python and Django.", tags: ["python", "coding", "tutorial"] },
  { id: "pandas", name: "Pandas exercises.ipynb", kind: "IPYNB", color: "#df8d37", modified: "Sep 7", summary: "Interactive Python notebook with data analysis exercises and solutions.", tags: ["python", "coding", "tutorial"] },
  { id: "automation", name: "Automate boring stuff.epub", kind: "EPUB", color: "#8b65bd", modified: "Aug 30", summary: "Python book about automating files, spreadsheets, websites, and email.", tags: ["python", "coding", "tutorial", "reinvention"] },
  { id: "workout", name: "12-week workout.pdf", kind: "PDF", color: "#e45454", modified: "Aug 24", summary: "Progressive strength and conditioning plan with a weekly schedule.", tags: ["workout", "fitness", "reinvention"] },
  { id: "japanese", name: "Learn Japanese.pdf", kind: "PDF", color: "#e45454", modified: "Aug 22", summary: "Beginner Japanese language workbook and daily practice plan.", tags: ["japan", "language", "reinvention"] },
  { id: "meditation", name: "Meditation guide.epub", kind: "EPUB", color: "#8b65bd", modified: "Aug 17", summary: "Thirty-day mindfulness and meditation program for beginners.", tags: ["wellness", "reinvention"] },
  { id: "productivity", name: "Deep work notes.md", kind: "MD", color: "#596b78", modified: "Aug 14", summary: "Notes and highlighted ideas about attention, focus, and productivity.", tags: ["productivity", "reinvention"] },
  { id: "guitar", name: "Guitar lessons.url", kind: "URL", color: "#4ca3a3", modified: "Aug 11", summary: "Online beginner guitar lesson series and practice calendar.", tags: ["music", "reinvention"] },
  { id: "resume", name: "New career résumé.docx", kind: "DOCX", color: "#3c73c9", modified: "Aug 8", summary: "Draft résumé tailored to software and product roles.", tags: ["career", "reinvention"] },

  { id: "rent", name: "September rent.pdf", kind: "PDF", color: "#e45454", modified: "Sep 1", summary: "Monthly apartment rent receipt and payment confirmation.", tags: ["finance", "receipt"] },
  { id: "electric", name: "Electric bill.pdf", kind: "PDF", color: "#e45454", modified: "Sep 1", summary: "Household electricity statement for August.", tags: ["finance", "bill"] },
  { id: "groceries", name: "Groceries receipt.jpg", kind: "JPG", color: "#6b9b62", modified: "Yesterday", summary: "Photo of a neighborhood grocery store receipt.", tags: ["receipt", "food"], photo: true },
  { id: "dog", name: "Milo at the beach.jpg", kind: "JPG", color: "#6b9b62", modified: "Sep 15", summary: "Photo of the dog running on a beach at sunset.", tags: ["photo", "personal"], photo: true },
  { id: "taxes", name: "2025 taxes.xlsx", kind: "XLSX", color: "#3d9a68", modified: "Sep 5", summary: "Personal tax calculations and deductible expenses.", tags: ["finance", "spreadsheet"] },
  { id: "recipe", name: "Sourdough recipe.pdf", kind: "PDF", color: "#e45454", modified: "Aug 31", summary: "Bread recipe with starter ratios and baking schedule.", tags: ["food", "recipe"] },
  { id: "meeting", name: "Team meeting notes.md", kind: "MD", color: "#596b78", modified: "Aug 29", summary: "Work meeting notes, decisions, owners, and next steps.", tags: ["work", "notes"] },
  { id: "invoice", name: "Camera invoice.pdf", kind: "PDF", color: "#e45454", modified: "Aug 21", summary: "Invoice for a mirrorless camera and lens purchase.", tags: ["receipt", "photo"] },
  { id: "party", name: "Birthday invite.png", kind: "PNG", color: "#6b9b62", modified: "Aug 16", summary: "Invitation image for Sam's birthday party next month.", tags: ["social", "event"], photo: true },
];

const $ = (selector) => document.querySelector(selector);
const fileLayer = $("#fileLayer");
const workspace = $("#workspace");
const folderInput = $("#folderName");
const offlinePreview = new URLSearchParams(location.search).has("offline");

let liveAvailable = false;
let debounceTimer;
let requestVersion = 0;
let composing = false;
let members = new Map();
let previousMemberIds = new Set();
let toastTimer;

function createCards() {
  const fragment = document.createDocumentFragment();
  for (const item of documents) {
    const card = document.createElement("div");
    card.className = "file-card";
    card.dataset.id = item.id;
    card.style.setProperty("--file-color", item.color);
    card.setAttribute("role", "img");
    card.setAttribute("aria-label", `${item.name}. ${item.summary}`);
    card.title = `${item.name}\n${item.summary}`;
    card.innerHTML = `
      <div class="file-visual${item.photo ? " photo" : ""}"><span class="file-type">${item.kind}</span></div>
      <span class="file-name">${item.name}</span>
      <span class="confidence"></span>`;
    fragment.append(card);
  }
  fileLayer.append(fragment);
}

function gridPositions(count, area) {
  if (!count) return [];
  const compact = area.width < 460;
  const columns = Math.max(1, Math.min(compact ? 4 : 6, Math.floor((area.width + 14) / 90)));
  const rows = Math.ceil(count / columns);
  const stepX = columns === 1 ? 0 : Math.max(90, Math.min(104, (area.width - 76) / (columns - 1)));
  const stepY = rows === 1 ? 0 : Math.max(58, Math.min(87, (area.height - 90) / (rows - 1)));
  return Array.from({ length: count }, (_, index) => ({
    x: area.x + (index % columns) * stepX,
    y: area.y + Math.floor(index / columns) * stepY,
  }));
}

function layoutCards(animate = false) {
  const width = workspace.clientWidth;
  const height = workspace.clientHeight;
  if (!width || !height) return;

  const inside = documents.filter((item) => members.get(item.id)?.belongs);
  const outside = documents.filter((item) => !members.get(item.id)?.belongs);
  const desktopPositions = gridPositions(outside.length, { x: 18, y: 36, width: width * .59, height: height - 46 });
  const folderPositions = gridPositions(inside.length, { x: width * .645, y: 82, width: width * .33, height: height - 104 });

  outside.forEach((item, index) => placeCard(item, desktopPositions[index], false, animate));
  inside.forEach((item, index) => placeCard(item, folderPositions[index], true, animate));
}

function placeCard(item, position, inside, animate) {
  const card = fileLayer.querySelector(`[data-id="${item.id}"]`);
  const wasInside = card.classList.contains("inside");
  card.style.setProperty("--x", `${Math.round(position.x)}px`);
  card.style.setProperty("--y", `${Math.round(position.y)}px`);
  card.classList.toggle("inside", inside);
  const confidence = members.get(item.id)?.confidence;
  card.querySelector(".confidence").textContent = confidence == null ? "" : `${Math.round(confidence * 100)}%`;
  if (animate && wasInside !== inside) {
    // Web Animations avoids forcing a synchronous layout for every moving card.
    const visual = card.querySelector(".file-visual");
    visual.getAnimations().forEach((animation) => animation.cancel());
    if (!window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      visual.animate([
        { transform: "translateY(0) scale(1)" },
        { transform: "translateY(-6px) scale(1.04)", offset: 0.38 },
        { transform: "translateY(0) scale(1)" },
      ], { duration: 420, easing: "cubic-bezier(.2,.82,.22,1)" });
    }
  }
}

function setThinking(active, message) {
  $("#thinkingDots").classList.toggle("show", active);
  $("#folderZone").classList.toggle("active", active);
  $("#thinkingStatus").textContent = message;
}

function demoClassify(name) {
  const phrase = name.toLowerCase();
  let wanted = [];
  if (/python/.test(phrase)) wanted = ["python"];
  else if (/airport/.test(phrase)) wanted = ["airport"];
  else if (/different person|reinvent|new me|change my life/.test(phrase)) wanted = ["reinvention"];
  else if (/japan|tokyo|kyoto/.test(phrase)) wanted = ["japan", "trip"];
  else {
    wanted = phrase.split(/\W+/).filter((word) => word.length > 4);
  }
  return documents.map((item) => {
    const hits = item.tags.filter((tag) => wanted.some((word) => tag.includes(word) || word.includes(tag))).length;
    const score = hits ? Math.min(.98, .72 + hits * .1) : .08;
    return { id: item.id, belongs: score >= .55, confidence: score };
  });
}

const classificationRequests = new IntentRequests(async (folderName) => {
  if (offlinePreview || !liveAvailable) return demoClassify(folderName);
  const response = await fetch("/api/classify", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      folder: folderName,
      documents: documents.map(({ id, name, kind, modified, summary }) => ({ id, name, kind, modified, summary })),
    }),
    signal: AbortSignal.timeout(22000),
  });
  const data = await response.json();
  if (!response.ok) throw new Error(data.error || "Jev could not classify these files.");
  return data.memberships;
});

async function classify(folderName, version) {
  setThinking(true, liveAvailable && !offlinePreview ? "Jev is reading the folder name…" : "Previewing the folder logic…");
  const started = performance.now();
  try {
    const result = await classificationRequests.get(folderName);
    if (!result || version !== requestVersion) return;
    applyMemberships(folderName, result, Math.round(performance.now() - started));
  } catch (error) {
    if (error.name === "AbortError" || version !== requestVersion) return;
    setThinking(false, error.message || "The folder could not update.");
    showToast(error.message || "The folder could not update.", true);
  }
}

function applyMemberships(folderName, result, elapsed) {
  previousMemberIds = new Set([...members.entries()].filter(([, value]) => value.belongs).map(([id]) => id));
  members = new Map(result.map((item) => [item.id, item]));
  const nextIds = new Set(result.filter((item) => item.belongs).map((item) => item.id));
  const joined = [...nextIds].filter((id) => !previousMemberIds.has(id)).length;
  const left = [...previousMemberIds].filter((id) => !nextIds.has(id)).length;
  const count = nextIds.size;

  layoutCards(true);
  $("#folderTitle").textContent = folderName;
  $("#matchCount").textContent = `${count} ${count === 1 ? "match" : "matches"}`;
  $("#looseCount").textContent = `${documents.length - count} scattered`;
  $("#statusSummary").textContent = `${documents.length} sample files · ${count} gathered`;
  $("#emptyFolder").classList.toggle("hidden", count > 0);
  setThinking(false, `${count} files belong here · ${elapsed} ms · keep typing to change it`);
  const message = previousMemberIds.size ? `${joined} joined · ${left} returned to desktop` : `${count} files gathered`;
  showToast(message);
}

function showToast(message, isError = false) {
  const toast = $("#movementToast");
  clearTimeout(toastTimer);
  toast.textContent = message;
  toast.classList.toggle("error", isError);
  toast.classList.add("show");
  toastTimer = setTimeout(() => toast.classList.remove("show"), 2200);
}

function clearFolder() {
  clearTimeout(debounceTimer);
  requestVersion += 1;
  classificationRequests.cancelQueued();
  members = new Map();
  previousMemberIds = new Set();
  folderInput.value = "";
  $("#folderTitle").textContent = "Your living folder";
  $("#matchCount").textContent = "Waiting for a name";
  $("#looseCount").textContent = "30 scattered";
  $("#statusSummary").textContent = "30 sample files · 0 gathered";
  $("#emptyFolder").classList.remove("hidden");
  setThinking(false, "No Enter key. The folder responds as you type.");
  document.querySelectorAll(".demo-beats button").forEach((button) => button.classList.remove("active"));
  layoutCards(true);
  folderInput.focus();
}

function scheduleClassification(event) {
  clearTimeout(debounceTimer);
  const version = ++requestVersion;
  classificationRequests.cancelQueued();
  const name = folderInput.value.trim().replace(/\s+/g, " ");
  document.querySelectorAll(".demo-beats button").forEach((button) => button.classList.toggle("active", button.dataset.folder === name));
  $("#folderTitle").textContent = name || "Your living folder";
  if (composing || event?.isComposing) return;
  if (name.length < 3) {
    if (!name) { clearFolder(); return; }
    setThinking(false, name ? "Keep typing—the idea is still too broad." : "No Enter key. The folder responds as you type.");
    return;
  }
  setThinking(true, "Updating folder…");
  // Space/paste/presets dispatch now; unfinished words get a short idle fallback.
  if (!event || /\s$/.test(folderInput.value) || event.inputType === "insertFromPaste") {
    classify(name, version);
  } else {
    debounceTimer = setTimeout(() => classify(name, version), 120);
  }
}

folderInput.addEventListener("input", scheduleClassification);
folderInput.addEventListener("compositionstart", () => {
  composing = true;
  clearTimeout(debounceTimer);
  requestVersion++;
  classificationRequests.cancelQueued();
});
folderInput.addEventListener("compositionend", () => {
  composing = false;
  scheduleClassification();
});
folderInput.addEventListener("keydown", (event) => {
  if (event.key === "Enter") event.preventDefault();
});
$("#clearName").addEventListener("click", clearFolder);
$("#newFolder").addEventListener("click", clearFolder);
document.querySelectorAll("[data-folder]").forEach((button) => {
  button.addEventListener("click", () => {
    folderInput.value = button.dataset.folder;
    scheduleClassification();
    folderInput.focus();
  });
});
window.addEventListener("resize", () => layoutCards(false));

async function initialize() {
  folderInput.disabled = true;
  createCards();
  layoutCards(false);
  try {
    const response = await fetch("/api/status");
    const status = await response.json();
    liveAvailable = status.configured;
  } catch {
    liveAvailable = false;
  }
  const mode = $("#mode");
  mode.classList.toggle("live", liveAvailable && !offlinePreview);
  mode.querySelector("span").textContent = liveAvailable && !offlinePreview ? "Jev ready" : "Offline preview";
  folderInput.disabled = false;
  folderInput.focus();
}

initialize();
