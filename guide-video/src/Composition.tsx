import {
  AbsoluteFill,
  Easing,
  Sequence,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";

const scenes = [
  {
    kicker: "QuickPod",
    title: "把长时间 Coding 任务稳稳挂在菜单栏",
    description:
      "防睡眠、休息提醒、快捷切换和屏幕清洁都放在一处。整个引导会在 25 秒内带你走一遍核心操作。",
    bullets: ["轻量常驻", "浅色玻璃界面", "适合长时间 AI 编码"],
  },
  {
    kicker: "01 / 权限",
    title: "先确认通知权限，辅助功能只作可选项",
    description:
      "当前版本的全局快捷键使用 Carbon RegisterEventHotKey，不依赖辅助功能。真正需要优先打开的是通知权限。",
    bullets: ["系统设置 → 通知", "允许 QuickPod 发送提醒", "辅助功能保留为可选"],
  },
  {
    kicker: "02 / 提醒",
    title: "启用休息提醒后，马上会收到一条确认通知",
    description:
      "选择 15/30/45/60 分钟任一档位，QuickPod 会先发一条“已开启”通知，再按周期提醒你离开屏幕活动一下。",
    bullets: ["即时确认", "周期提醒", "可测试通知链路"],
  },
  {
    kicker: "03 / 防睡眠",
    title: "防睡眠更适合长任务：开始就有系统反馈",
    description:
      "开启后会立刻收到 macOS 通知，状态栏会维持明确反馈。适合视频渲染、代码生成、长时训练和下载任务。",
    bullets: ["不限时 / 定时", "状态栏反馈", "结束后自动恢复正常休眠"],
  },
  {
    kicker: "04 / 快捷键",
    title: "按住快捷键呼出圆盘，松手即收起",
    description:
      "最后一页演示 Quick Switcher。你可以快速开关防睡眠、启动提醒、清洁屏幕，或者直接回到设置窗口。",
    bullets: ["按住显示", "松手关闭", "一圈完成常用操作"],
  },
] as const;

const palette = {
  ink: "#1F2937",
  sub: "#607086",
  line: "#D7E1EC",
  soft: "#EEF4FA",
  card: "rgba(255,255,255,0.86)",
  accent: "#47B36B",
  amber: "#E9B949",
  red: "#E05D5D",
  blue: "#6A8CFF",
};

const sceneDuration = 150;

export const QuickPodGuideComposition = () => {
  return (
    <AbsoluteFill
      style={{
        background:
          "radial-gradient(circle at top left, #f3f8ff 0%, #eef5fb 35%, #f9fbfe 72%, #edf3f8 100%)",
        color: palette.ink,
        fontFamily:
          '"SF Pro Display","PingFang SC","Hiragino Sans GB","Microsoft YaHei",sans-serif',
      }}
    >
      <FloatingBackground />
      {scenes.map((scene, index) => (
        <Sequence
          key={scene.kicker}
          from={index * sceneDuration}
          durationInFrames={sceneDuration}
        >
          <GuideScene index={index} {...scene} />
        </Sequence>
      ))}
    </AbsoluteFill>
  );
};

const FloatingBackground = () => {
  const frame = useCurrentFrame();

  return (
    <>
      <div
        style={{
          position: "absolute",
          width: 520,
          height: 520,
          borderRadius: 999,
          background: "radial-gradient(circle, rgba(122,176,255,0.24), transparent 70%)",
          left: interpolate(frame, [0, 780], [80, 200]),
          top: -120,
          filter: "blur(10px)",
        }}
      />
      <div
        style={{
          position: "absolute",
          width: 420,
          height: 420,
          borderRadius: 999,
          background: "radial-gradient(circle, rgba(86,204,136,0.18), transparent 70%)",
          right: interpolate(frame, [0, 780], [40, 140]),
          bottom: -80,
          filter: "blur(8px)",
        }}
      />
    </>
  );
};

const GuideScene = ({
  kicker,
  title,
  description,
  bullets,
  index,
}: {
  kicker: string;
  title: string;
  description: string;
  bullets: readonly string[];
  index: number;
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const entrance = spring({
    frame,
    fps,
    durationInFrames: 24,
    config: {
      damping: 16,
      stiffness: 120,
      mass: 0.9,
    },
  });

  const fadeOut = interpolate(frame, [120, 145], [1, 0], {
    easing: Easing.out(Easing.cubic),
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        opacity: fadeOut,
        transform: `translateY(${interpolate(entrance, [0, 1], [42, 0])}px)`,
        padding: "68px 72px",
        display: "grid",
        gridTemplateColumns: "1.05fr 0.95fr",
        gap: 36,
      }}
    >
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          justifyContent: "space-between",
        }}
      >
        <div>
          <div
            style={{
              display: "inline-flex",
              alignItems: "center",
              gap: 10,
              borderRadius: 999,
              background: "rgba(255,255,255,0.78)",
              border: `1px solid ${palette.line}`,
              padding: "10px 16px",
              boxShadow: "0 12px 30px rgba(30,48,79,0.06)",
              color: palette.sub,
              fontSize: 20,
              fontWeight: 600,
              letterSpacing: 0.4,
            }}
          >
            <div
              style={{
                width: 10,
                height: 10,
                borderRadius: 99,
                background: palette.accent,
              }}
            />
            {kicker}
          </div>
          <h1
            style={{
              fontSize: 62,
              lineHeight: 1.08,
              margin: "24px 0 18px",
              letterSpacing: -1.8,
            }}
          >
            {title}
          </h1>
          <p
            style={{
              margin: 0,
              fontSize: 26,
              lineHeight: 1.6,
              color: palette.sub,
              maxWidth: 680,
            }}
          >
            {description}
          </p>
        </div>

        <div
          style={{
            display: "flex",
            gap: 14,
            flexWrap: "wrap",
          }}
        >
          {bullets.map((bullet) => (
            <div
              key={bullet}
              style={{
                padding: "12px 18px",
                borderRadius: 999,
                background: "rgba(255,255,255,0.72)",
                border: `1px solid ${palette.line}`,
                fontSize: 21,
                color: palette.ink,
                boxShadow: "0 10px 24px rgba(31,41,55,0.06)",
              }}
            >
              {bullet}
            </div>
          ))}
        </div>
      </div>

      <SceneMockup index={index} />
    </AbsoluteFill>
  );
};

const SceneMockup = ({ index }: { index: number }) => {
  const commonCard: React.CSSProperties = {
    position: "relative",
    borderRadius: 36,
    background: palette.card,
    border: `1px solid rgba(215,225,236,0.95)`,
    boxShadow: "0 30px 80px rgba(45,64,89,0.12)",
    backdropFilter: "blur(20px)",
    overflow: "hidden",
  };

  return (
    <div
      style={{
        display: "grid",
        placeItems: "center",
      }}
    >
      <div
        style={{
          ...commonCard,
          width: "100%",
          height: "100%",
          minHeight: 560,
          padding: 30,
        }}
      >
        <TopBar />
        {index === 0 ? <WelcomeMockup /> : null}
        {index === 1 ? <PermissionMockup /> : null}
        {index === 2 ? <ReminderMockup /> : null}
        {index === 3 ? <AntiSleepMockup /> : null}
        {index === 4 ? <HotkeyMockup /> : null}
      </div>
    </div>
  );
};

const TopBar = () => (
  <div
    style={{
      display: "flex",
      alignItems: "center",
      gap: 10,
      marginBottom: 24,
    }}
  >
    {["#FF6F61", "#F7C948", "#59C784"].map((color) => (
      <div
        key={color}
        style={{
          width: 14,
          height: 14,
          borderRadius: 999,
          background: color,
        }}
      />
    ))}
    <div
      style={{
        marginLeft: 10,
        color: palette.sub,
        fontSize: 18,
        letterSpacing: 0.2,
      }}
    >
      QuickPod walkthrough
    </div>
  </div>
);

const SectionCard = ({
  title,
  subtitle,
  right,
}: {
  title: string;
  subtitle: string;
  right?: React.ReactNode;
}) => (
  <div
    style={{
      padding: "18px 20px",
      borderRadius: 24,
      border: `1px solid ${palette.line}`,
      background: "rgba(255,255,255,0.74)",
      display: "flex",
      justifyContent: "space-between",
      alignItems: "center",
      marginBottom: 14,
    }}
  >
    <div>
      <div style={{ fontSize: 24, fontWeight: 700 }}>{title}</div>
      <div style={{ fontSize: 18, color: palette.sub, marginTop: 6 }}>{subtitle}</div>
    </div>
    {right}
  </div>
);

const WelcomeMockup = () => (
  <div style={{ display: "grid", gridTemplateColumns: "1.1fr 0.9fr", gap: 20 }}>
    <div>
      <SectionCard
        title="QuickPod 设置"
        subtitle="状态栏快捷操作、提醒、文件模板"
        right={<Ring progress={0.76} color={palette.accent} label="45:00" animated />}
      />
      <SectionCard
        title="防睡眠"
        subtitle="长时间任务中保持 Mac 唤醒"
        right={<ToggleBadge label="ON" color={palette.accent} />}
      />
      <SectionCard
        title="休息提醒"
        subtitle="开启后按周期推送休息通知"
        right={<ToggleBadge label="45 min" color={palette.amber} />}
      />
      <SectionCard
        title="快捷键"
        subtitle="按住显示，松手关闭"
        right={<ShortcutChip text="⌘⌥Space" />}
      />
    </div>
    <div
      style={{
        borderRadius: 30,
        background: "linear-gradient(180deg, #F5FBFF 0%, #EAF5EC 100%)",
        border: `1px solid ${palette.line}`,
        padding: 26,
      }}
    >
      <div style={{ fontSize: 20, color: palette.sub, marginBottom: 16 }}>
        状态栏预览
      </div>
      <div
        style={{
          background: "rgba(255,255,255,0.9)",
          borderRadius: 24,
          padding: 20,
          display: "flex",
          flexDirection: "column",
          gap: 18,
        }}
      >
        <Ring progress={0.76} color={palette.accent} label="44:59" large animated />
        <MiniLine color={palette.accent} text="圆环图标实时显示剩余进度" />
        <MiniLine color={palette.blue} text="菜单栏常驻，不打断桌面工作流" />
        <SignatureWave />
      </div>
    </div>
  </div>
);

const PermissionMockup = () => (
  <div style={{ display: "grid", gap: 18 }}>
    <SectionCard
      title="通知权限"
      subtitle="用于休息提醒和状态确认通知"
      right={<ToggleBadge label="允许" color={palette.accent} />}
    />
    <SectionCard
      title="辅助功能（可选）"
      subtitle="当前全局快捷键不依赖此权限"
      right={<ToggleBadge label="可选" color={palette.blue} />}
    />
    <div
      style={{
        marginTop: 12,
        borderRadius: 28,
        border: `1px dashed ${palette.line}`,
        background: "rgba(250,252,255,0.9)",
        padding: 24,
      }}
    >
      {[
        "打开系统设置",
        "进入“通知”",
        "找到 QuickPod 并允许通知",
      ].map((step, index) => (
        <div
          key={step}
          style={{
            display: "flex",
            alignItems: "center",
            gap: 14,
            marginBottom: index === 2 ? 0 : 16,
          }}
        >
          <div
            style={{
              width: 34,
              height: 34,
              borderRadius: 999,
              background: "#E9F7EF",
              color: palette.accent,
              display: "grid",
              placeItems: "center",
              fontWeight: 800,
            }}
          >
            {index + 1}
          </div>
          <div style={{ fontSize: 22 }}>{step}</div>
        </div>
      ))}
    </div>
  </div>
);

const ReminderMockup = () => (
  <div style={{ display: "grid", gap: 20 }}>
    <SectionCard
      title="休息提醒已开启"
      subtitle="QuickPod 将在 45 分钟后提醒你休息"
      right={<ToggleBadge label="即时通知" color={palette.accent} />}
    />
    <div
      style={{
        display: "grid",
        gridTemplateColumns: "1fr 1fr",
        gap: 18,
      }}
    >
      <div
        style={{
          borderRadius: 28,
          background: "#F8FBFD",
          border: `1px solid ${palette.line}`,
          padding: 24,
        }}
      >
        <div style={{ fontSize: 20, color: palette.sub, marginBottom: 18 }}>
          倒计时
        </div>
        <Ring progress={0.63} color={palette.amber} label="28:12" large animated />
      </div>
      <div
        style={{
          borderRadius: 28,
          background: "#FEFBF2",
          border: `1px solid ${palette.line}`,
          padding: 24,
          display: "flex",
          flexDirection: "column",
          justifyContent: "space-between",
        }}
      >
        <div style={{ fontSize: 20, color: palette.sub }}>提醒方式</div>
        <ShortcutChip text="系统通知 + 弹窗" fullWidth />
        <MiniLine color={palette.amber} text="支持测试通知与周期确认" />
      </div>
    </div>
  </div>
);

const AntiSleepMockup = () => (
  <div style={{ display: "grid", gap: 18 }}>
    <SectionCard
      title="防睡眠已开启"
      subtitle="Mac 将保持唤醒，直到任务结束"
      right={<ToggleBadge label="ON" color={palette.accent} />}
    />
    <div
      style={{
        display: "grid",
        gridTemplateColumns: "1fr 1fr",
        gap: 18,
      }}
    >
      <div
        style={{
          borderRadius: 30,
          background: "linear-gradient(180deg, #EEF9F2 0%, #F9FCFF 100%)",
          border: `1px solid ${palette.line}`,
          padding: 24,
        }}
      >
        <div style={{ fontSize: 20, color: palette.sub, marginBottom: 18 }}>
          会话时长
        </div>
        <div style={{ display: "grid", gap: 12 }}>
          {["15 分钟", "30 分钟", "1 小时", "不限时"].map((item, index) => (
            <div
              key={item}
              style={{
                padding: "14px 16px",
                borderRadius: 18,
                background: index === 3 ? "#DFF4E5" : "rgba(255,255,255,0.88)",
                border: `1px solid ${palette.line}`,
                fontSize: 20,
              }}
            >
              {item}
            </div>
          ))}
        </div>
      </div>
      <div
        style={{
          borderRadius: 30,
          background: "rgba(255,255,255,0.72)",
          border: `1px solid ${palette.line}`,
          padding: 24,
          display: "flex",
          flexDirection: "column",
          justifyContent: "space-between",
        }}
      >
        <MiniLine color={palette.accent} text="开始就发系统通知" />
        <MiniLine color={palette.blue} text="状态栏图标保持同步反馈" />
        <MiniLine color={palette.red} text="结束后恢复默认休眠策略" />
      </div>
    </div>
  </div>
);

const HotkeyMockup = () => (
  <div
    style={{
      height: "100%",
      display: "grid",
      placeItems: "center",
      position: "relative",
    }}
  >
    <div
      style={{
        width: 360,
        height: 360,
        borderRadius: 999,
        position: "relative",
        background: "radial-gradient(circle, rgba(255,255,255,0.96) 0%, rgba(244,249,255,0.88) 58%, rgba(232,241,249,0.64) 100%)",
        boxShadow: "0 20px 60px rgba(76,96,128,0.18)",
      }}
    >
      {[
        ["防睡眠", 0, palette.accent],
        ["提醒", 72, palette.amber],
        ["清洁", 144, palette.blue],
        ["文件", 216, "#A96CE2"],
        ["设置", 288, palette.red],
      ].map(([label, angle, color]) => {
        const radians = (Number(angle) * Math.PI) / 180;
        const radius = 128;
        const x = Math.cos(radians) * radius;
        const y = Math.sin(radians) * radius;

        return (
          <div
            key={label}
            style={{
              position: "absolute",
              left: 180 + x - 46,
              top: 180 + y - 46,
              width: 92,
              height: 92,
              borderRadius: 999,
              background: color as string,
              display: "grid",
              placeItems: "center",
              color: "white",
              fontSize: 22,
              fontWeight: 700,
              boxShadow: `0 16px 36px ${String(color)}44`,
            }}
          >
            {label}
          </div>
        );
      })}
      <div
        style={{
          position: "absolute",
          inset: 116,
          borderRadius: 999,
          background: "#122033",
          color: "white",
          display: "grid",
          placeItems: "center",
          fontSize: 26,
          fontWeight: 700,
        }}
      >
        ⌘⌥Space
      </div>
    </div>
  </div>
);

const Ring = ({
  progress,
  color,
  label,
  large = false,
  animated = false,
}: {
  progress: number;
  color: string;
  label: string;
  large?: boolean;
  animated?: boolean;
}) => {
  const frame = useCurrentFrame();
  const size = large ? 184 : 116;
  const stroke = large ? 14 : 10;
  const radius = (size - stroke) / 2;
  const circumference = 2 * Math.PI * radius;
  const dashOffset = circumference * (1 - progress);
  const pulse = animated ? 1 + Math.sin(frame / 14) * 0.016 : 1;
  const highlightAngle = animated ? frame * 0.055 : 0;
  const glowX = size / 2 + Math.cos(highlightAngle) * radius;
  const glowY = size / 2 + Math.sin(highlightAngle) * radius;

  return (
    <div
      style={{
        width: size,
        height: size,
        position: "relative",
        display: "grid",
        placeItems: "center",
        transform: `scale(${pulse})`,
      }}
    >
      <svg width={size} height={size} style={{ transform: "rotate(-90deg)" }}>
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke="rgba(31,41,55,0.12)"
          strokeWidth={stroke}
        />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke={color}
          strokeWidth={stroke}
          strokeDasharray={circumference}
          strokeDashoffset={dashOffset}
          strokeLinecap="round"
          style={{
            filter: animated ? "drop-shadow(0 0 10px rgba(71,179,107,0.22))" : undefined,
          }}
        />
      </svg>
      {animated ? (
        <div
          style={{
            position: "absolute",
            width: large ? 18 : 12,
            height: large ? 18 : 12,
            borderRadius: 999,
            background: color,
            boxShadow: `0 0 0 ${large ? 10 : 6}px ${color}22`,
            left: glowX - (large ? 9 : 6),
            top: glowY - (large ? 9 : 6),
          }}
        />
      ) : null}
      <div
        style={{
          position: "absolute",
          textAlign: "center",
        }}
      >
        <div style={{ fontSize: large ? 34 : 24, fontWeight: 800 }}>{label}</div>
        <div style={{ fontSize: large ? 16 : 13, color: palette.sub }}>remaining</div>
      </div>
    </div>
  );
};

const SignatureWave = () => {
  const frame = useCurrentFrame();
  const travel = interpolate(frame % 90, [0, 89], [0, 212], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <div
      style={{
        position: "relative",
        height: 34,
        borderRadius: 999,
        background: "linear-gradient(90deg, rgba(71,179,107,0.08), rgba(106,140,255,0.12))",
        overflow: "hidden",
      }}
    >
      <div
        style={{
          position: "absolute",
          left: 16,
          right: 16,
          top: 16,
          height: 2,
          borderRadius: 999,
          background: "rgba(31,41,55,0.08)",
        }}
      />
      <div
        style={{
          position: "absolute",
          left: 16 + travel,
          top: 9,
          width: 16,
          height: 16,
          borderRadius: 999,
          background: palette.accent,
          boxShadow: "0 0 0 10px rgba(71,179,107,0.18)",
        }}
      />
    </div>
  );
};

const ToggleBadge = ({ label, color }: { label: string; color: string }) => (
  <div
    style={{
      minWidth: 108,
      padding: "10px 16px",
      borderRadius: 999,
      color,
      background: `${color}18`,
      border: `1px solid ${color}55`,
      textAlign: "center",
      fontWeight: 700,
      fontSize: 18,
    }}
  >
    {label}
  </div>
);

const ShortcutChip = ({
  text,
  fullWidth = false,
}: {
  text: string;
  fullWidth?: boolean;
}) => (
  <div
    style={{
      padding: "16px 18px",
      borderRadius: 22,
      background: "#132033",
      color: "white",
      fontSize: 22,
      fontWeight: 700,
      textAlign: "center",
      width: fullWidth ? "100%" : "auto",
    }}
  >
    {text}
  </div>
);

const MiniLine = ({ color, text }: { color: string; text: string }) => (
  <div
    style={{
      display: "flex",
      alignItems: "center",
      gap: 12,
      fontSize: 20,
      color: palette.ink,
    }}
  >
    <div
      style={{
        width: 10,
        height: 10,
        borderRadius: 999,
        background: color,
      }}
    />
    {text}
  </div>
);
