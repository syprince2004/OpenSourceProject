const axios = require('axios');

// 사용자의 채팅 메시지를 받아 AI 모델의 응답을 반환하는 컨트롤러
exports.getAiChatResponse = async (req, res) => {
    // 1. 사용자 요청 본문(body)에서 데이터 추출
    const { userMessage, conversationHistory } = req.body;

    // 2. 입력값 유효성 검사
    // userMessage가 비어있거나 없으면 400 Bad Request 에러를 반환하여 서버 안정성 확보
    if (!userMessage || userMessage.trim() === '') {
        return res.status(400).json({ 
            success: false, 
            message: 'userMessage는 필수 항목입니다.' 
        });
    }

    try {
        // 3. Ollama API URL을 환경 변수에서 가져오기
        const ollamaApiUrl = process.env.OLLAMA_API_URL;
        if (!ollamaApiUrl) {
            // 환경 변수가 설정되지 않은 경우 에러를 발생시켜 문제를 빠르게 인지하도록 함
            throw new Error('OLLAMA_API_URL이 환경 변수에 설정되지 않았습니다.');
        }

        // 4. AI의 역할을 정의하는 시스템 프롬프트 추가
        const systemPrompt = `
            너는 한국어 사용자와 대화하는 똑똑한 AI 어시스턴트야.
            사용자의 방 정리, 청소, 정돈과 관련된 질문에 대해
            구체적이고 실용적이며 친절하게 답변해야 해.
            절대 영어로 답하지 말고 항상 한국어로만 답변해.
        `;

        // 5. 이전 대화 기록을 문자열로 변환
        let conversationStr = "";
        if (conversationHistory && conversationHistory.length > 0) {
            conversationStr = conversationHistory
                .map(msg => `${msg.role === 'user' ? '사용자' : 'AI'}: ${msg.content}`)
                .join('\n');
        }

        // 6. 최종 프롬프트 조합
          const finalPrompt = `
            ${systemPrompt}

            [이전 대화]
            ${conversationStr}

            [사용자의 질문]
            사용자: ${userMessage}

            [AI의 답변]
                    `;

        // 7. API 호출
        const ollamaResponse = await axios.post(`${ollamaApiUrl}/api/generate`, {
            model: "llama3", // 모델 바꿀 때마다 설치하고 이름만 바꾸면 됨
            prompt: finalPrompt,
            stream: false
        });

        const aiMessage = ollamaResponse.data.response;

        // 8. Flutter 앱으로 최종 AI 응답 전송
        res.status(200).json({
            success: true,
            message: aiMessage.trim() // 답변 앞뒤의 불필요한 공백 제거
        });

    } catch (error) {
        console.error('Ollama API 호출 중 오류 발생:', error.message);
        res.status(500).json({ 
            success: false, 
            message: 'AI 어시스턴트를 호출하는 데 실패했습니다.' 
        });
    }
};