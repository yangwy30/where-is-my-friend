// Cloudflare Pages Function for https://acrossus.app/trips/join/<trip invitation id>.
// Serves the static trip invite page with an "Open in Across Us" link for that invitation.

const INVITATION_ID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

export async function onRequestGet({ params, request, env }) {
  const id = String(params.id ?? "").toLowerCase();
  if (!INVITATION_ID.test(id)) {
    return Response.redirect(new URL("/", request.url), 302);
  }

  const page = await env.ASSETS.fetch(new URL("/trips/join/", request.url));
  return new HTMLRewriter()
    .on("[data-open-app]", {
      element: (el) => el.setAttribute("href", `whereismyfriend://trips/join/${id}`),
    })
    .transform(page);
}
