// Cloudflare Pages Function for https://acrossus.app/i/<username>.
// Serves the static invite page with the inviter's username in the title and
// link-preview tags, so iMessage and other apps show who sent the invite.

const USERNAME = /^[a-z0-9_]{3,20}$/;

function normalize(raw) {
  let value = String(raw ?? "");
  try {
    value = decodeURIComponent(value);
  } catch {
    return null;
  }
  value = value.trim().replace(/^@+/, "").toLowerCase();
  return USERNAME.test(value) ? value : null;
}

export async function onRequestGet({ params, request, env }) {
  const username = normalize(params.username);
  if (!username) {
    return Response.redirect(new URL("/", request.url), 302);
  }

  const page = await env.ASSETS.fetch(new URL("/i/", request.url));
  const title = `@${username} invited you to Across Us`;

  return new HTMLRewriter()
    .on("title", { element: (el) => el.setInnerContent(title) })
    .on('meta[property="og:title"]', { element: (el) => el.setAttribute("content", title) })
    .on('meta[property="og:url"]', {
      element: (el) => el.setAttribute("content", `https://acrossus.app/i/${username}`),
    })
    .on("[data-invite-name]", { element: (el) => el.setInnerContent(`@${username}`) })
    .on("[data-open-app]", {
      element: (el) => el.setAttribute("href", `whereismyfriend://invite/${username}`),
    })
    .transform(page);
}
