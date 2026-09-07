export default {
  async fetch(request: Request): Promise<Response> {
    const incoming = new URL(request.url);
    const target = new URL("https://skygrid.my");
    target.pathname = incoming.pathname;
    target.search = incoming.search;
    return Response.redirect(target.href, 301);
  }
} satisfies ExportedHandler;
