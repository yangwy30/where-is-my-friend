// A bare /trips/join/ has no invitation, so send visitors to the homepage.
export function onRequestGet({ request }) {
  return Response.redirect(new URL("/", request.url), 302);
}
