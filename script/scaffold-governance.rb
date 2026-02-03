#!/usr/bin/env ruby
# frozen_string_literal: true

# 新專案治理 scaffold：建立目標目錄並複製 .cursor 治理與 docs 範本
# 用法：ruby script/scaffold-governance.rb <目標根目錄> [專案顯示名稱]
# 例：ruby script/scaffold-governance.rb C:\github\my_new_project "我的新專案"

require "fileutils"

SOURCE_ROOT = File.expand_path("..", __dir__)
TARGET_ROOT = ARGV[0]
PROJECT_NAME = ARGV[1] || "新專案"

abort "用法：ruby script/scaffold-governance.rb <目標根目錄> [專案顯示名稱]" if TARGET_ROOT.to_s.strip.empty?

def mkdir_p(path)
  FileUtils.mkdir_p(path)
  puts "  建立目錄：#{path}"
end

def copy(src, dest)
  return unless File.file?(src)
  FileUtils.mkdir_p(File.dirname(dest))
  FileUtils.cp(src, dest, preserve: true)
  puts "  複製：#{File.basename(src)} -> #{dest.gsub(TARGET_ROOT, "")}"
end

def write(path, content)
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, content)
  puts "  寫入：#{path.gsub(TARGET_ROOT, "")}"
end

puts "Scaffold 治理模式 → #{TARGET_ROOT}（專案名稱：#{PROJECT_NAME}）"
puts ""

# 目錄結構
mkdir_p(File.join(TARGET_ROOT, ".cursor", "rules"))
mkdir_p(File.join(TARGET_ROOT, ".cursor", "skills", "requirements-elicitation"))
mkdir_p(File.join(TARGET_ROOT, ".cursor", "skills", "scaffold-new-project"))
mkdir_p(File.join(TARGET_ROOT, ".cursor", "skills", "soft-eng-from-client-to-dev"))
mkdir_p(File.join(TARGET_ROOT, "docs"))
mkdir_p(File.join(TARGET_ROOT, "docs", "from-client-to-dev"))

# 複製 .cursor 治理
copy(File.join(SOURCE_ROOT, ".cursor", "RULES-AND-SKILLS-建議.md"), File.join(TARGET_ROOT, ".cursor", "RULES-AND-SKILLS-建議.md"))
Dir.glob(File.join(SOURCE_ROOT, ".cursor", "rules", "*.mdc")).each do |f|
  copy(f, File.join(TARGET_ROOT, ".cursor", "rules", File.basename(f)))
end
copy(File.join(SOURCE_ROOT, ".cursor", "skills", "requirements-elicitation", "SKILL.md"),
     File.join(TARGET_ROOT, ".cursor", "skills", "requirements-elicitation", "SKILL.md"))
copy(File.join(SOURCE_ROOT, ".cursor", "skills", "scaffold-new-project", "SKILL.md"),
     File.join(TARGET_ROOT, ".cursor", "skills", "scaffold-new-project", "SKILL.md"))
copy(File.join(SOURCE_ROOT, ".cursor", "skills", "soft-eng-from-client-to-dev", "SKILL.md"),
     File.join(TARGET_ROOT, ".cursor", "skills", "soft-eng-from-client-to-dev", "SKILL.md"))

# 複製「從客戶到交付開發」軟體工程文件範本（00～10 + README）
Dir.glob(File.join(SOURCE_ROOT, "docs", "from-client-to-dev", "*.md")).each do |f|
  copy(f, File.join(TARGET_ROOT, "docs", "from-client-to-dev", File.basename(f)))
end

# 複製 AI 開發標準與專案標準文件
copy(File.join(SOURCE_ROOT, "docs", "15-AI-DEV-STANDARDS.md"), File.join(TARGET_ROOT, "docs", "15-AI-DEV-STANDARDS.md"))
copy(File.join(SOURCE_ROOT, "docs", "16-PROJECT-STANDARD.md"), File.join(TARGET_ROOT, "docs", "16-PROJECT-STANDARD.md"))
copy(File.join(SOURCE_ROOT, "docs", "17-PRODUCTIVITY-AND-QUALITY.md"), File.join(TARGET_ROOT, "docs", "17-PRODUCTIVITY-AND-QUALITY.md"))

# 複製 scaffold 腳本到新專案，以便新專案也能再 scaffold 下一個專案
mkdir_p(File.join(TARGET_ROOT, "script"))
copy(File.join(SOURCE_ROOT, "script", "scaffold-governance.rb"), File.join(TARGET_ROOT, "script", "scaffold-governance.rb"))

# docs 範本（通用版，不含本專案特定內容）
write(File.join(TARGET_ROOT, "docs", "README.md"), <<~MD)
  # 專案治理與維護文件索引

  本目錄存放 **#{PROJECT_NAME}** 的願景、目標、規劃與行動清單，供開發與維護時引用。

  | 文件 | 說明 | 引用時機 |
  |------|------|----------|
  | [01-VISION-AND-GOALS.md](01-VISION-AND-GOALS.md) | 結論、專案定位、技術棧 | 新成員 onboarding、決策依據、對外說明 |
  | [02-ROADMAP.md](02-ROADMAP.md) | 階段規劃 | 排程、sprint、功能開發順序 |
  | [03-USER-STORY.md](03-USER-STORY.md) | 使用情境與流程 | 驗收條件、測試情境、產品說明 |
  | [04-NEXT-ACTIONS.md](04-NEXT-ACTIONS.md) | 下一步行動與前置條件 | 開工前檢查、交接、維運手冊 |

  ---

  **維護約定**

  * 重大目標或階段完成時，請更新對應文件與「目前進度」。
  * 引用時請使用相對路徑，例如：`見 docs/02-ROADMAP.md`。
  * 新增治理文件時，請在此索引補上一列。
MD

write(File.join(TARGET_ROOT, "docs", "01-VISION-AND-GOALS.md"), <<~MD)
  # 1. 願景與目標

  > 維護時可引用：**專案定位、技術選型、對外一句話說明**。

  ---

  ## 1.1 結論先行

  **專案名稱：** #{PROJECT_NAME}

  **一句話說明：** （待補）

  **定位：** （待補）

  ---

  ## 1.2 專案全貌與核心架構

  ### 專案名稱與代號

  | 項目 | 內容 |
  |------|------|
  | **代號** | （待補，例如 repo 名稱） |
  | **定位** | （待補） |

  ### 核心技術棧 (Tech Stack)

  | 角色 | 技術 | 說明 |
  |------|------|------|
  | （待補） | （待補） | （待補） |

  ---

  **維護約定**：目標或技術變更時請更新本文件。
MD

write(File.join(TARGET_ROOT, "docs", "02-ROADMAP.md"), <<~MD)
  # 2. 專案執行規劃 (Roadmap)

  > 維護時可引用：**階段劃分、目前進度、各階段工作內容**。

  ---

  ## 階段總覽

  | 階段 | 名稱 | 狀態 | 目標摘要 |
  |------|------|------|----------|
  | 第 0 階段 | （待補） | 待開始 | （待補） |
  | 第 1 階段 | （待補） | 待開始 | （待補） |

  ---

  **維護約定**：階段完成或新增時請更新本表與對應章節。
MD

write(File.join(TARGET_ROOT, "docs", "03-USER-STORY.md"), <<~MD)
  # 3. 使用者故事與情境

  > 維護時可引用：**使用情境、驗收條件、產品說明**。

  ---

  ## 主要使用情境

  （待補：誰、在什麼情境、做什麼步驟、得到什麼結果。）

  ---

  ## 驗收條件

  （待補：可對應需求文件之驗收條件。）
MD

write(File.join(TARGET_ROOT, "docs", "04-NEXT-ACTIONS.md"), <<~MD)
  # 4. 下一步行動與前置條件

  > 維護時可引用：**開工前檢查、交接、維運手冊**。

  ---

  ## 開工前檢查

  * （待補：環境、金鑰、權限等）
  * （待補）

  ---

  ## 目前下一步

  * （待補）
MD

puts ""
puts "完成。請在 Cursor 中開啟目標目錄：#{TARGET_ROOT}"
puts "治理規則與 docs 已就緒，可依專案需求編輯 docs 內容與 .cursor/rules。"
puts "若新專案非 Windows/Rails，可刪除或修改 .cursor/rules/windows-env.mdc。"
