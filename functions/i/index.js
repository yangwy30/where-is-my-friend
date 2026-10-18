// A bare /i/ has no inviter, so send visitors to the homepage.
export function onRequestGet({ request }) {
  return Response.redirect(new URL("/", request.url), 302);
}
