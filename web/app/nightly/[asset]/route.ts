import { redirectToReleaseAsset } from "../../lib/coterm-release-assets";

export const dynamic = "force-dynamic";

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ asset: string }> }
) {
  const { asset } = await params;
  if (!/^coterm-nightly-macos-\d+\.dmg$/.test(asset)) {
    return new Response("Not found", { status: 404 });
  }
  return redirectToReleaseAsset(`nightly/${asset}`);
}
