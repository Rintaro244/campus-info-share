/**
 * C4 ドメイン例外。Dart 側 C4Exception（code: 400/404/409/500/502/503）と同じ取り決め。
 * core ロジックはこの型で投げ、index.ts の薄いラッパが HttpsError 等へ変換する。
 */
export class CoreError extends Error {
  constructor(
    public readonly code: number,
    message: string,
  ) {
    super(message);
    this.name = 'CoreError';
  }
}
