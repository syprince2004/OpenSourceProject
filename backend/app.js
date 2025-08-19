const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

const indexRouter = require('./routes/index');
const chatRoutes = require('./routes/chatRoutes');

// JSON 파서의 용량 제한을 50MB로 넉넉하게 늘림
app.use(express.json({limit : '50mb'}));
// URL 인코딩된 데이터를 파싱하기 위한 미들웨어 추가
app.use(express.urlencoded({ extended: false, limit: '50mb' }));

// 모든 응답에 UTF-8 Content-Type 헤더 설정
app.use((req, res, next) => {
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  next();
});

app.use('/api', indexRouter);
app.use('/api/chat', chatRoutes);

app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});