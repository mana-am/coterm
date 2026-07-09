import { NextRequest, NextResponse } from "next/server";

export const dynamic = "force-dynamic";

type ClerkAuthLike = {
  userId: string | null;
};

type NativeSignInHandlerDependencies = {
  getAuth: () => Promise<ClerkAuthLike>;
};

export function makeNativeSignInHandler(dependencies: NativeSignInHandlerDependencies) {
  void dependencies;
  return async function GET(request: NextRequest) {
    void request;
    return new NextResponse(null, { status: 404 });
  };
}

export const GET = makeNativeSignInHandler({ getAuth: async () => ({ userId: null }) });
