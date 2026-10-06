const config = window.SUPABASE_CONFIG || {};
const client =
  window.supabase && config.url && config.publishableKey
    ? window.supabase.createClient(config.url, config.publishableKey)
    : null;

const form = document.getElementById("loginForm");
const emailInput = document.getElementById("loginEmail");
const passwordInput = document.getElementById("loginPassword");
const loginButton = document.getElementById("loginButton");
const message = document.getElementById("loginMessage");

const allowedNext = [
  "platform-dashboard.html",
  "customers.html",
  "subscriptions.html",
  "analytics.html",
  "settings.html",
  "index.html",
  "dashboard.html",
  "menu.html",
  "restaurant-customers.html",
  "staff.html",
  "reports.html",
  "profile.html",
  "subscription.html"
];

const requestedNext = new URLSearchParams(window.location.search).get("next");
const nextPage = allowedNext.includes(requestedNext)
  ? requestedNext
  : "index.html";

form.addEventListener("submit", async (event) => {
  event.preventDefault();

  loginButton.disabled = true;
  loginButton.textContent = "Signing in...";
  message.textContent = "";

  try {
    if (!client) {
      throw new Error("Supabase is not configured.");
    }

    const { error } = await client.auth.signInWithPassword({
      email: emailInput.value.trim(),
      password: passwordInput.value
    });

    if (error) {
      throw error;
    }

    window.location.replace(nextPage);
  } catch (error) {
    message.textContent = error?.message || "Unable to sign in.";
  } finally {
    loginButton.disabled = false;
    loginButton.textContent = "Sign In";
  }
});
