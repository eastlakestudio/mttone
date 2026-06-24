import React, { useState, useEffect } from "react";
import "./index.css";
import { invoke as tauriInvoke } from "@tauri-apps/api/core";
import { listen as tauriListen } from "@tauri-apps/api/event";

const isTauri = typeof window !== "undefined" && (window as any).__TAURI_INTERNALS__ !== undefined;

// 兼容浏览器直接预览调试的 Tauri 代理调用
const invoke = async (cmd: string, args?: any) => {
  if (isTauri) {
    return await tauriInvoke(cmd, args);
  }
  
  console.log(`[Mock Invoke] ${cmd}`, args);
  // 提供前端预览专用的模拟数据返回
  if (cmd === "get_ollama_models_cmd") {
    return [
      { name: "gemma4:2b", size: 2160000000 },
      { name: "qwen2.5:3b", size: 3100000000 }
    ];
  } else if (cmd === "get_active_model_cmd") {
    return (window as any).__MOCK_ACTIVE_MODEL__ || "gemma4:2b";
  } else if (cmd === "set_active_model_cmd") {
    (window as any).__MOCK_ACTIVE_MODEL__ = args.modelName;
    return `Active model set to ${args.modelName}`;
  } else if (cmd === "pull_ollama_model_cmd") {
    await new Promise((resolve) => setTimeout(resolve, 3000));
    return `Model ${args.modelName} pulled successfully`;
  }
  return null;
};

interface TranscriptLine {
  id: string;
  speaker: string;
  originalText: string;
  cleanedText?: string;
  time: string;
}

interface SpeakerCard {
  label: string;
  suggestedName: string;
  actualName: string;
  isBound: boolean;
  audioClipPath: string;
}

interface LocalModel {
  name: String;
  size: number;
}

export default function App() {
  // 状态管理
  const [isRecording, setIsRecording] = useState(false);
  const [meetingStatus, setMeetingStatus] = useState<"idle" | "recording" | "reviewing">("idle");
  const [transcript, setTranscript] = useState<TranscriptLine[]>([]);
  const [speakers, setSpeakers] = useState<SpeakerCard[]>([]);
  const [activePlayClip, setActivePlayClip] = useState<string | null>(null);

  // 会议元数据状态
  const [showMeetingModal, setShowMeetingModal] = useState(false);
  const [meetingTitle, setMeetingTitle] = useState("");
  const [meetingLocation, setMeetingLocation] = useState("");
  const [meetingAttendees, setMeetingAttendees] = useState(""); // 预留给参会人
  const [parentMeetingId, setParentMeetingId] = useState("");

  // 大模型管理状态
  const [showModelManager, setShowModelManager] = useState(false);
  const [ollamaConnected, setOllamaConnected] = useState(false);
  const [localModels, setLocalModels] = useState<LocalModel[]>([]);
  const [activeModel, setActiveModel] = useState("gemma4:2b");
  const [newModelName, setNewModelName] = useState("");
  const [pulling, setPulling] = useState(false);

  // 轮询检查 Ollama 状态与已下载模型
  const checkOllamaStatus = async () => {
    try {
      const models = await invoke("get_ollama_models_cmd");
      setLocalModels(models);
      setOllamaConnected(true);
      
      const active = await invoke("get_active_model_cmd");
      setActiveModel(active);
    } catch (e) {
      console.warn("Unable to fetch Ollama status", e);
      setOllamaConnected(false);
    }
  };

  useEffect(() => {
    // 初始化数据库
    const initDb = async () => {
      try {
        await invoke("initialize_db_cmd", { dbPath: "mttone.db" });
        console.log("Database initialized");
      } catch (e) {
        console.error("Database initialization failed", e);
      }
    };
    initDb();

    checkOllamaStatus();
    // 每 10 秒刷新一次连接状态
    const interval = setInterval(checkOllamaStatus, 10000);
    return () => clearInterval(interval);
  }, []);

  // 切换运行的大模型
  const handleSwitchModel = async (name: string) => {
    try {
      await invoke("set_active_model_cmd", { modelName: name });
      setActiveModel(name);
      alert(`已成功将本地 LLM 切换为: ${name}`);
    } catch (e) {
      alert("切换失败: " + e);
    }
  };

  // 下载/拉取新模型
  const handlePullModel = async () => {
    if (!newModelName) return;
    setPulling(true);
    try {
      await invoke("pull_ollama_model_cmd", { modelName: newModelName });
      alert(`模型 ${newModelName} 下载成功！`);
      setNewModelName("");
      checkOllamaStatus();
    } catch (e) {
      alert("下载模型失败: " + e);
    } finally {
      setPulling(false);
    }
  };

  // 模拟流式转写数据源
  const mockTranscriptPool = [
    { speaker: "Speaker_1", text: "大家上午好，飞书会议的音频连接已经正常了。", time: "10:00" },
    { speaker: "Speaker_2", text: "我觉得研发侧大概需要两周时间做本地 VAD 和 Whisper 的端侧优化。", time: "10:01" },
    { speaker: "Speaker_1", text: "李工说的对，另外声纹识别在手机端比对时，千万注意控制功耗，别发烫。", time: "10:02" },
    { speaker: "Speaker_3", text: "我是王华，我们产品这边的设计稿已经定稿了，可以随时同步到项目库里。", time: "10:03" },
    { speaker: "Speaker_2", text: "王华，把你那边的设计稿导出一份 Markdown 文档同步给我。", time: "10:04" }
  ];

  // 监听录制过程中的流式转写推送
  useEffect(() => {
    let unlisten: (() => void) | undefined;
    
    if (isRecording) {
      if (isTauri) {
        tauriListen<any>("transcript-segment", (event) => {
          const seg = event.payload;
          setTranscript((prev) => {
            // 避免重复追加相同 ID 的段落
            if (prev.some((line) => line.id === seg.id)) {
              return prev;
            }
            const mins = Math.floor(seg.start_time / 60);
            const secs = Math.floor(seg.start_time % 60);
            const timeStr = `${mins.toString().padStart(2, "0")}:${secs.toString().padStart(2, "0")}`;
            return [
              ...prev,
              {
                id: seg.id,
                speaker: seg.speaker_label,
                originalText: seg.text,
                time: timeStr
              }
            ];
          });
        }).then((fn) => {
          unlisten = fn;
        });
      } else {
        // 浏览器环境下的模拟退回
        let step = 0;
        const interval = setInterval(() => {
          if (step < mockTranscriptPool.length) {
            const nextLine = mockTranscriptPool[step];
            setTranscript((prev) => [
              ...prev,
              {
                id: `line-${step}`,
                speaker: nextLine.speaker,
                originalText: nextLine.text,
                time: nextLine.time
              }
            ]);
            step++;
          } else {
            setIsRecording(false);
            setMeetingStatus("reviewing");
          }
        }, 3500);
        return () => clearInterval(interval);
      }
    }
    
    return () => {
      if (unlisten) {
        unlisten();
      }
    };
  }, [isRecording]);

  // 开始录音
  const startRecording = async () => {
    setShowMeetingModal(false);
    
    // 生成一个测试 ID，实际中应当用 UUID
    const newMeetingId = `meeting_${Date.now()}`;
    const defaultTitle = meetingTitle || `会议记录_${new Date().toLocaleDateString()}`;
    
    try {
      // 1. 调用创建会议 DB
      await invoke("create_meeting_cmd", {
        id: newMeetingId,
        parentMeetingId: parentMeetingId || null,
        title: defaultTitle,
        location: meetingLocation || null,
        audioPath: `/tmp/audio_${newMeetingId}.wav` // Mock 路径
      });
      // 2. 调用录音指令
      await invoke("start_recording_cmd", { meetingId: newMeetingId });
      
      setTranscript([]);
      setSpeakers([]);
      setIsRecording(true);
      setMeetingStatus("recording");
    } catch (e) {
      console.error("Tauri record cmd error:", e);
      alert(`无法启动录音: ${e}`);
    }
  };

  // 停止录音，进入整理看板
  const stopRecording = async () => {
    try {
      await invoke("stop_recording_cmd");
    } catch (e) {
      console.warn("Tauri stop record cmd error", e);
    }
    setIsRecording(false);
    setMeetingStatus("reviewing");
    
    // 初始化临时发言人卡片 (AI 智能猜人与试听切片)
    setSpeakers([
      {
        label: "Speaker_1",
        suggestedName: "张总",
        actualName: "",
        isBound: false,
        audioClipPath: "clip_speaker_1.wav"
      },
      {
        label: "Speaker_2",
        suggestedName: "李工",
        actualName: "",
        isBound: false,
        audioClipPath: "clip_speaker_2.wav"
      },
      {
        label: "Speaker_3",
        suggestedName: "王华",
        actualName: "",
        isBound: false,
        audioClipPath: "clip_speaker_3.wav"
      }
    ]);
  };

  // 绑定真实姓名，执行“全局对齐”
  const bindSpeakerName = (label: string, name: string) => {
    setSpeakers((prev) =>
      prev.map((s) => (s.label === label ? { ...s, actualName: name, isBound: true } : s))
    );

    // 1. 全局对齐：替换转写文本中对应的 speaker 标签
    setTranscript((prev) =>
      prev.map((line) => (line.speaker === label ? { ...line, speaker: name } : line))
    );
  };

  // 试听声纹切片模拟
  const playClip = (clipPath: string) => {
    setActivePlayClip(clipPath);
    setTimeout(() => {
      setActivePlayClip(null);
    }, 2000);
  };

  // 口语净化模拟：修改部分语句，有些语句保持原样
  const purifyText = async () => {
    try {
      // 触发后端真实大模型处理以做日志输出
      await invoke("process_text_cmd", { meetingId: "test-id" });
    } catch (e) {
      console.warn("Local Ollama offline, using rules fallback", e);
    }

    setTranscript((prev) =>
      prev.map((line) => {
        let cleaned = line.originalText;
        if (line.originalText.includes("我觉得")) {
          cleaned = line.originalText
            .replace("我觉得", "预计")
            .replace("大概需要", "需要");
        } else if (line.originalText.includes("对，特别是")) {
          cleaned = line.originalText.replace("对，特别是", "特别是");
        }
        return { ...line, cleanedText: cleaned };
      })
    );
  };

  // 编辑行状态
  const [editingLineId, setEditingLineId] = useState<string | null>(null);
  const [editText, setEditText] = useState("");

  const startEditing = (id: string, currentText: string) => {
    setEditingLineId(id);
    setEditText(currentText);
  };

  const saveEdit = (id: string) => {
    setTranscript((prev) =>
      prev.map((line) =>
        line.id === id ? { ...line, cleanedText: editText, originalText: editText } : line
      )
    );
    setEditingLineId(null);
  };

  // 渲染行内修订差异
  const renderRevision = (line: TranscriptLine) => {
    if (!line.cleanedText || line.originalText === line.cleanedText) {
      return <span style={{ color: "hsl(var(--text-primary))" }}>{line.originalText}</span>;
    }

    const elements: React.ReactNode[] = [];
    if (line.originalText.includes("我觉得")) {
      elements.push(
        <del key="del1" style={{ color: "hsl(var(--danger))", textDecoration: "line-through", marginRight: "4px" }}>我觉得</del>,
        <ins key="ins1" style={{ color: "hsl(var(--success))", textDecoration: "underline", marginRight: "4px", fontWeight: 600 }}>预计</ins>,
        "研发侧",
        <del key="del2" style={{ color: "hsl(var(--danger))", textDecoration: "line-through", mx: "4px", marginLeft: "4px", marginRight: "4px" }}>大概需要</del>,
        <ins key="ins2" style={{ color: "hsl(var(--success))", textDecoration: "underline", marginRight: "4px", fontWeight: 600 }}>需要</ins>,
        "两周时间做本地 VAD 和 Whisper 的端侧优化。"
      );
    } else if (line.originalText.includes("对，特别是")) {
      elements.push(
        <del key="del1" style={{ color: "hsl(var(--danger))", textDecoration: "line-through", marginRight: "4px" }}>对，特别是</del>,
        <ins key="ins1" style={{ color: "hsl(var(--success))", textDecoration: "underline", marginRight: "4px", fontWeight: 600 }}>特别是</ins>,
        "声纹比对和本地大模型的运行效率，千万不能发烫。"
      );
    } else {
      return <span style={{ color: "hsl(var(--text-primary))" }}>{line.cleanedText}</span>;
    }

    return <span style={{ display: "inline-flex", flexWrap: "wrap", alignItems: "center" }}>{elements}</span>;
  };

  return (
    <div style={{ padding: "40px 20px", maxWidth: "1000px", margin: "0 auto" }}>
      {/* 头部 */}
      <header style={{ marginBottom: "32px", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <div style={{ textAlign: "left" }}>
          <h1 style={{ fontSize: "2.5rem", fontWeight: 800, background: "linear-gradient(135deg, #fff 0%, #a8a29e 100%)", WebkitBackgroundClip: "text", WebkitTextFillColor: "transparent", letterSpacing: "-0.04em" }}>
            Mttone
          </h1>
          <p style={{ color: "hsl(var(--text-secondary))", marginTop: "4px", fontSize: "0.95rem" }}>
            本地离线会议纪要与声纹人脉库
          </p>
        </div>
        <button
          onClick={() => setShowModelManager(!showModelManager)}
          className="glass-panel"
          style={{
            padding: "8px 16px",
            borderRadius: "var(--radius-md)",
            border: "1px solid rgba(255,255,255,0.12)",
            color: "#fff",
            cursor: "pointer",
            fontSize: "0.85rem",
            fontWeight: 600,
            display: "flex",
            alignItems: "center",
            gap: "6px"
          }}
        >
          🤖 {showModelManager ? "关闭管理" : "Ollama 模型管理"}
        </button>
      </header>

      {/* Ollama 模型管理器面板 */}
      {showModelManager && (
        <div className="glass-panel" style={{ padding: "20px", borderRadius: "var(--radius-lg)", marginBottom: "24px", animation: "fadeIn 0.3s ease" }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", borderBottom: "1px solid rgba(255,255,255,0.1)", paddingBottom: "12px", marginBottom: "16px" }}>
            <h3 style={{ fontSize: "1.1rem", fontWeight: 700 }}>Ollama 本地引擎管理</h3>
            <div style={{ display: "flex", alignItems: "center", gap: "6px", fontSize: "0.85rem" }}>
              <span>连接状态:</span>
              <span style={{ color: ollamaConnected ? "hsl(var(--success))" : "hsl(var(--danger))", fontWeight: 700 }}>
                {ollamaConnected ? "🟢 已连接 (127.0.0.1:11434)" : "🔴 未检测到服务，请开启 Ollama"}
              </span>
            </div>
          </div>

          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "24px" }}>
            {/* 已下载模型列表 */}
            <div>
              <h4 style={{ fontSize: "0.95rem", color: "hsl(var(--text-secondary))", marginBottom: "10px" }}>本地可用模型列表</h4>
              {localModels.length === 0 ? (
                <p style={{ color: "hsl(var(--text-muted))", fontSize: "0.85rem" }}>本地暂无可用模型，请在右侧下载。</p>
              ) : (
                <div style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
                  {localModels.map((model) => (
                    <div
                      key={model.name}
                      style={{
                        padding: "10px 12px",
                        borderRadius: "var(--radius-sm)",
                        background: activeModel === model.name ? "var(--primary-glow)" : "rgba(255,255,255,0.03)",
                        border: activeModel === model.name ? "1px solid hsl(var(--primary))" : "1px solid rgba(255,255,255,0.08)",
                        display: "flex",
                        justifyContent: "space-between",
                        alignItems: "center"
                      }}
                    >
                      <div>
                        <div style={{ fontWeight: 600, fontSize: "0.9rem" }}>{model.name}</div>
                        <div style={{ fontSize: "0.75rem", color: "hsl(var(--text-muted))" }}>
                          大小: {(model.size / 1024 / 1024 / 1024).toFixed(2)} GB
                        </div>
                      </div>
                      {activeModel === model.name ? (
                        <span style={{ color: "hsl(var(--success))", fontSize: "0.75rem", fontWeight: 700 }}>活动中</span>
                      ) : (
                        <button
                          onClick={() => handleSwitchModel(model.name)}
                          style={{
                            background: "rgba(255,255,255,0.1)",
                            border: "none",
                            color: "#fff",
                            padding: "4px 8px",
                            borderRadius: "4px",
                            fontSize: "0.75rem",
                            cursor: "pointer"
                          }}
                        >
                          应用
                        </button>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* 下载新模型 */}
            <div>
              <h4 style={{ fontSize: "0.95rem", color: "hsl(var(--text-secondary))", marginBottom: "10px" }}>拉取/下载新模型</h4>
              <p style={{ fontSize: "0.8rem", color: "hsl(var(--text-muted))", marginBottom: "12px" }}>
                输入模型名称（例如 <code>gemma4:2b</code> 或 <code>qwen2.5:3b</code>），点击下载自动下载至本地。
              </p>
              <div style={{ display: "flex", gap: "8px" }}>
                <input
                  type="text"
                  value={newModelName}
                  onChange={(e) => setNewModelName(e.target.value)}
                  placeholder="如 gemma4:2b"
                  disabled={pulling}
                  style={{
                    flex: 1,
                    background: "rgba(0,0,0,0.3)",
                    border: "1px solid rgba(255,255,255,0.15)",
                    borderRadius: "var(--radius-sm)",
                    color: "#fff",
                    padding: "8px 12px",
                    fontSize: "0.9rem"
                  }}
                />
                <button
                  onClick={handlePullModel}
                  disabled={pulling || !newModelName}
                  style={{
                    background: pulling ? "rgba(255,255,255,0.1)" : "hsl(var(--primary))",
                    color: "#fff",
                    border: "none",
                    padding: "8px 16px",
                    borderRadius: "var(--radius-sm)",
                    cursor: pulling ? "not-allowed" : "pointer",
                    fontSize: "0.9rem",
                    fontWeight: 600
                  }}
                >
                  {pulling ? "📥 下载中" : "下载"}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* 会议配置弹窗 */}
      {showMeetingModal && (
        <div style={{
          position: "fixed", top: 0, left: 0, right: 0, bottom: 0,
          background: "rgba(0,0,0,0.6)", backdropFilter: "blur(4px)",
          display: "flex", justifyContent: "center", alignItems: "center",
          zIndex: 1000
        }}>
          <div className="glass-panel" style={{ padding: "30px", borderRadius: "var(--radius-lg)", width: "400px" }}>
            <h3 style={{ fontSize: "1.2rem", fontWeight: 700, marginBottom: "20px" }}>新建/延续会议录制</h3>
            
            <div style={{ display: "flex", flexDirection: "column", gap: "16px", marginBottom: "24px" }}>
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", color: "hsl(var(--text-secondary))", marginBottom: "6px" }}>会议主题</label>
                <input
                  type="text"
                  value={meetingTitle}
                  onChange={(e) => setMeetingTitle(e.target.value)}
                  placeholder="例如：产品周会"
                  style={{ width: "100%", background: "rgba(0,0,0,0.3)", border: "1px solid rgba(255,255,255,0.15)", borderRadius: "var(--radius-sm)", color: "#fff", padding: "8px 12px" }}
                />
              </div>
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", color: "hsl(var(--text-secondary))", marginBottom: "6px" }}>会议地点</label>
                <input
                  type="text"
                  value={meetingLocation}
                  onChange={(e) => setMeetingLocation(e.target.value)}
                  placeholder="例如：会议室 A"
                  style={{ width: "100%", background: "rgba(0,0,0,0.3)", border: "1px solid rgba(255,255,255,0.15)", borderRadius: "var(--radius-sm)", color: "#fff", padding: "8px 12px" }}
                />
              </div>
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", color: "hsl(var(--text-secondary))", marginBottom: "6px" }}>参会人 (可选)</label>
                <input
                  type="text"
                  value={meetingAttendees}
                  onChange={(e) => setMeetingAttendees(e.target.value)}
                  placeholder="例如：张总，李工"
                  style={{ width: "100%", background: "rgba(0,0,0,0.3)", border: "1px solid rgba(255,255,255,0.15)", borderRadius: "var(--radius-sm)", color: "#fff", padding: "8px 12px" }}
                />
              </div>
              <div>
                <label style={{ display: "block", fontSize: "0.85rem", color: "hsl(var(--text-secondary))", marginBottom: "6px" }}>延续历史会议 ID (可选)</label>
                <input
                  type="text"
                  value={parentMeetingId}
                  onChange={(e) => setParentMeetingId(e.target.value)}
                  placeholder="填写上一次会议 ID"
                  style={{ width: "100%", background: "rgba(0,0,0,0.3)", border: "1px solid rgba(255,255,255,0.15)", borderRadius: "var(--radius-sm)", color: "#fff", padding: "8px 12px" }}
                />
              </div>
            </div>

            <div style={{ display: "flex", justifyContent: "flex-end", gap: "12px" }}>
              <button
                onClick={() => setShowMeetingModal(false)}
                style={{ background: "rgba(255,255,255,0.1)", border: "none", color: "#fff", padding: "8px 16px", borderRadius: "var(--radius-sm)", cursor: "pointer" }}
              >
                取消
              </button>
              <button
                onClick={startRecording}
                style={{ background: "hsl(var(--primary))", border: "none", color: "#fff", padding: "8px 24px", borderRadius: "var(--radius-sm)", cursor: "pointer", fontWeight: 600 }}
              >
                开始录音
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 控制中心 */}
      <div className="glass-panel" style={{ borderRadius: "var(--radius-lg)", padding: "20px", marginBottom: "24px", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <div>
          <span style={{ fontSize: "0.9rem", color: "hsl(var(--text-muted))" }}>系统状态</span>
          <h2 style={{ fontSize: "1.3rem", fontWeight: 600, marginTop: "4px" }}>
            {meetingStatus === "idle" && "💤 准备就绪"}
            {meetingStatus === "recording" && "🔴 会中实时录音与 ASR 分段中..."}
            {meetingStatus === "reviewing" && "✨ 会后声纹整理看板"}
          </h2>
        </div>
        <div style={{ display: "flex", gap: "12px" }}>
          {meetingStatus !== "recording" ? (
            <button
              onClick={() => setShowMeetingModal(true)}
              style={{
                background: "hsl(var(--primary))",
                color: "#fff",
                border: "none",
                padding: "10px 24px",
                borderRadius: "var(--radius-md)",
                cursor: "pointer",
                fontWeight: 600,
                transition: "var(--transition-fast)"
              }}
            >
              开始新录音
            </button>
          ) : (
            <button
              onClick={stopRecording}
              style={{
                background: "hsl(var(--danger))",
                color: "#fff",
                border: "none",
                padding: "10px 24px",
                borderRadius: "var(--radius-md)",
                cursor: "pointer",
                fontWeight: 600,
                transition: "var(--transition-fast)"
              }}
            >
              结束录音
            </button>
          )}

          {meetingStatus === "reviewing" && (
            <button
              onClick={purifyText}
              style={{
                background: "rgba(255,255,255,0.08)",
                color: "#fff",
                border: "1px solid rgba(255,255,255,0.15)",
                padding: "10px 24px",
                borderRadius: "var(--radius-md)",
                cursor: "pointer",
                fontWeight: 600
              }}
            >
              ✨ 口语净化 (LLM)
            </button>
          )}
        </div>
      </div>

      {/* 主面板布局 */}
      <div style={{ display: "grid", gridTemplateColumns: meetingStatus === "reviewing" ? "320px 1fr" : "1fr", gap: "24px" }}>
        
        {/* 侧边栏/左面板：声纹库后置绑定 */}
        {meetingStatus === "reviewing" && (
          <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
            <h3 style={{ fontSize: "1.1rem", fontWeight: 600, color: "hsl(var(--text-secondary))" }}>声纹分离卡片</h3>
            
            {speakers.map((spk) => (
              <div
                key={spk.label}
                className="glass-panel"
                style={{
                  padding: "16px",
                  borderRadius: "var(--radius-md)",
                  border: spk.isBound ? "1px solid hsla(var(--success), 0.3)" : "1px solid rgba(255,255,255,0.08)"
                }}
              >
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "12px" }}>
                  <span style={{ fontWeight: 700, fontSize: "0.95rem" }}>{spk.label}</span>
                  <button
                    onClick={() => playClip(spk.audioClipPath)}
                    style={{
                      background: activePlayClip === spk.audioClipPath ? "hsl(var(--accent))" : "rgba(255,255,255,0.1)",
                      border: "none",
                      color: "#fff",
                      fontSize: "0.8rem",
                      padding: "4px 8px",
                      borderRadius: "4px",
                      cursor: "pointer"
                    }}
                  >
                    {activePlayClip === spk.audioClipPath ? "🔊 播音中" : "▶️ 试听 5s"}
                  </button>
                </div>

                {!spk.isBound ? (
                  <div>
                    {/* 智能小抄提示 */}
                    <div
                      style={{
                        background: "var(--primary-glow)",
                        border: "1px solid hsla(var(--primary), 0.3)",
                        padding: "8px",
                        borderRadius: "var(--radius-sm)",
                        fontSize: "0.8rem",
                        marginBottom: "10px",
                        color: "hsl(var(--text-primary))"
                      }}
                    >
                      💡 AI 猜测可能是 <strong>{spk.suggestedName}</strong>
                    </div>
                    <div style={{ display: "flex", gap: "8px" }}>
                      <button
                        onClick={() => bindSpeakerName(spk.label, spk.suggestedName)}
                        style={{
                          background: "hsl(var(--primary))",
                          border: "none",
                          color: "#fff",
                          fontSize: "0.8rem",
                          padding: "6px 12px",
                          borderRadius: "4px",
                          cursor: "pointer",
                          flex: 1
                        }}
                      >
                        确认绑定
                      </button>
                      <input
                        type="text"
                        placeholder="手动姓名"
                        onKeyDown={(e) => {
                          if (e.key === "Enter") {
                            bindSpeakerName(spk.label, (e.target as HTMLInputElement).value);
                          }
                        }}
                        style={{
                          width: "80px",
                          background: "rgba(0,0,0,0.3)",
                          border: "1px solid rgba(255,255,255,0.15)",
                          borderRadius: "4px",
                          color: "#fff",
                          padding: "4px",
                          fontSize: "0.8rem"
                        }}
                      />
                    </div>
                  </div>
                ) : (
                  <div style={{ color: "hsl(var(--success))", fontSize: "0.9rem", fontWeight: 600 }}>
                    已成功对齐为: {spk.actualName}
                  </div>
                )}
              </div>
            ))}
          </div>
        )}

        {/* 右面板/主面板：发言流滚动与纪要整理 */}
        <div className="glass-panel" style={{ borderRadius: "var(--radius-lg)", padding: "24px", minHeight: "400px" }}>
          <h3 style={{ fontSize: "1.2rem", fontWeight: 600, marginBottom: "20px", borderBottom: "1px solid rgba(255,255,255,0.1)", paddingBottom: "12px" }}>
            实时转写与分轨发言流
          </h3>

          {transcript.length === 0 ? (
            <div style={{ display: "flex", justifyContent: "center", alignItems: "center", height: "300px", color: "hsl(var(--text-muted))" }}>
              暂无会议发言记录，点击“开始新录音”启动本地 ASR。
            </div>
          ) : (
            <div style={{ display: "flex", flexDirection: "column", gap: "20px" }}>
              {transcript.map((line) => (
                <div key={line.id} style={{ display: "flex", flexDirection: "column", gap: "4px" }}>
                  <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                    <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
                      <span
                        style={{
                          fontWeight: 700,
                          color: line.speaker.startsWith("Speaker_") ? "hsl(var(--accent))" : "hsl(var(--primary-hover))",
                          fontSize: "0.95rem"
                        }}
                      >
                        {line.speaker}
                      </span>
                      <span style={{ fontSize: "0.75rem", color: "hsl(var(--text-muted))" }}>{line.time}</span>
                    </div>
                    {meetingStatus === "reviewing" && editingLineId !== line.id && (
                      <button
                        onClick={() => startEditing(line.id, line.cleanedText || line.originalText)}
                        style={{
                          background: "none",
                          border: "none",
                          color: "hsl(var(--text-muted))",
                          cursor: "pointer",
                          fontSize: "0.8rem",
                          display: "flex",
                          alignItems: "center",
                          gap: "4px"
                        }}
                      >
                        ✏️ 修改
                      </button>
                    )}
                  </div>
                  
                  <div style={{ display: "flex", flexDirection: "column", gap: "2px" }}>
                    {editingLineId === line.id ? (
                      <div style={{ display: "flex", flexDirection: "column", gap: "8px", marginTop: "4px" }}>
                        <textarea
                          value={editText}
                          onChange={(e) => setEditText(e.target.value)}
                          style={{
                            width: "100%",
                            minHeight: "60px",
                            background: "rgba(0,0,0,0.4)",
                            border: "1px solid hsl(var(--primary))",
                            borderRadius: "var(--radius-sm)",
                            color: "#fff",
                            padding: "8px",
                            fontSize: "0.95rem",
                            fontFamily: "inherit"
                          }}
                        />
                        <div style={{ display: "flex", gap: "8px", justifyContent: "flex-end" }}>
                          <button
                            onClick={() => setEditingLineId(null)}
                            style={{
                              background: "rgba(255,255,255,0.08)",
                              border: "1px solid rgba(255,255,255,0.15)",
                              color: "#fff",
                              padding: "4px 12px",
                              borderRadius: "4px",
                              fontSize: "0.8rem",
                              cursor: "pointer"
                            }}
                          >
                            取消
                          </button>
                          <button
                            onClick={() => saveEdit(line.id)}
                            style={{
                              background: "hsl(var(--primary))",
                              border: "none",
                              color: "#fff",
                              padding: "4px 12px",
                              borderRadius: "4px",
                              fontSize: "0.8rem",
                              cursor: "pointer"
                            }}
                          >
                            保存
                          </button>
                        </div>
                      </div>
                    ) : (
                      renderRevision(line)
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

      </div>
    </div>
  );
}
