// LLM API 호출 (선택). 서버는 lib 밖 server/ 폴더 (FastAPI)
// 카톡 분석 · 가이드 규칙에서 필요할 때 사용
// 가짜: 아직 서버에 연결하지 않음
class LlmClient {
  /// 서버 주소
  static const baseUrl = '';

  /// 질문을 보내고 답을 받음
  Future<String> ask(String prompt) async => '';
}
