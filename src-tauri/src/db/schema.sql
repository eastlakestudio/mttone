-- 1. 联系人表 (声纹库)
CREATE TABLE IF NOT EXISTS contacts (
    id TEXT PRIMARY KEY,                       -- UUID
    name TEXT NOT NULL,                        -- 真实姓名/备注姓名 (如: 张总, 客户A)
    avatar_url TEXT,                           -- 头像路径
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. 会议记录表
CREATE TABLE IF NOT EXISTS meetings (
    id TEXT PRIMARY KEY,                       -- UUID
    parent_meeting_id TEXT,                    -- 延续的历史会议 ID (可为空)
    title TEXT NOT NULL,                       -- 会议主题/名称
    location TEXT,                             -- 会议地点
    audio_path TEXT NOT NULL,                  -- 原始完整音频文件的本地路径
    duration INTEGER NOT NULL,                 -- 会议时长 (秒)
    status TEXT NOT NULL CHECK(status IN ('recording', 'pending_diarization', 'processing_llm', 'completed')), 
                                               -- 会议状态机状态
    summary TEXT,                              -- AI 生成的净化结构化会议纪要
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (parent_meeting_id) REFERENCES meetings(id) ON DELETE SET NULL
);

-- 2.1. 私域知识库文档表
CREATE TABLE IF NOT EXISTS documents (
    id TEXT PRIMARY KEY,                       -- UUID
    filename TEXT NOT NULL,                    -- 文档名称
    file_path TEXT NOT NULL,                   -- 本地文件路径
    text_content TEXT,                         -- 解析出的文本内容
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2.2. 会议与文档的多对多关联表
CREATE TABLE IF NOT EXISTS meeting_document_bindings (
    meeting_id TEXT NOT NULL,
    document_id TEXT NOT NULL,
    PRIMARY KEY (meeting_id, document_id),
    FOREIGN KEY (meeting_id) REFERENCES meetings(id) ON DELETE CASCADE,
    FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
);

-- 3. 发言切片表 (包含 ASR 文本与 Diarization 分轨信息)
CREATE TABLE IF NOT EXISTS speech_clips (
    id TEXT PRIMARY KEY,                       -- UUID
    meeting_id TEXT NOT NULL,                  -- 关联会议 ID
    speaker_label TEXT NOT NULL,               -- 声纹分离出来的临时标签 (如: Speaker_1, Speaker_2)
    contact_id TEXT,                           -- 绑定后的联系人 ID (可为空，后置绑定时更新)
    start_time REAL NOT NULL,                  -- 发言开始时间 (秒，支持浮点数)
    end_time REAL NOT NULL,                    -- 发言结束时间 (秒，支持浮点数)
    original_text TEXT NOT NULL,               -- ASR 原始流式转写文本
    cleaned_text TEXT,                         -- LLM 净化后的口语净化文本
    audio_clip_path TEXT,                      -- 该段发言的音频切片路径 (前3个识别度高的切片路径，用于前端试听)
    is_key_clip INTEGER DEFAULT 0,             -- 是否为代表该 speaker 的核心试听切片 (0: 否, 1: 是)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (meeting_id) REFERENCES meetings(id) ON DELETE CASCADE,
    FOREIGN KEY (contact_id) REFERENCES contacts(id) ON DELETE SET NULL
);

-- 4. 载入 sqlite-vss 扩展并创建声纹向量表
-- 512 表示 CAM++ 或 PyAnnote 提取的 512 维声纹特征向量
-- 阶段 1 暂不开启（避免缺少 sqlite-vss 扩展导致建表失败）
-- CREATE VIRTUAL TABLE IF NOT EXISTS voiceprints_vss USING vss0(
--     speech_clip_id TEXT,                       -- 关联的发言切片 ID
--     contact_id TEXT,                           -- 关联的联系人 ID (可为空)
--     voiceprint_vector(512)                     -- 512维声纹特征向量
-- );
