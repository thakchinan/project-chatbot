#!/usr/bin/env python3
import os
import sys
import subprocess
import json
import urllib.request
import urllib.error
import argparse

# Default settings
DEFAULT_MODEL = "gemini-2.5-flash"
REVIEW_FILE = "GEMINI_CODE_REVIEW.md"

def get_git_diff(staged=False, branch=None):
    """Retrieves the git diff content from the repository."""
    try:
        # Check if we are inside a git repository
        subprocess.run(
            ["git", "rev-parse", "--is-inside-work-tree"],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("❌ ข้อผิดพลาด: โฟลเดอร์ปัจจุบันไม่ใช่ Git Repository หรือตรวจไม่พบคำสั่ง 'git'", file=sys.stderr)
        return None

    cmd = ["git", "diff"]
    if staged:
        cmd.append("--cached")
    elif branch:
        cmd.append(branch)

    try:
        result = subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, errors="replace")
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"❌ เกิดข้อผิดพลาดในการดึง Git Diff: {e.stderr}", file=sys.stderr)
        return None

def load_api_key_from_env_file():
    """Tries to find and load GEMINI_API_KEY from .env files in the current folder."""
    env_paths = [".env", "../.env"]
    for path in env_paths:
        if os.path.exists(path):
            try:
                with open(path, "r", encoding="utf-8") as f:
                    for line in f:
                        line = line.strip()
                        if line and not line.startswith("#") and "=" in line:
                            key, val = line.split("=", 1)
                            if key.strip() == "GEMINI_API_KEY":
                                return val.strip().strip('"').strip("'")
            except Exception as e:
                print(f"⚠️ ไม่สามารถเปิดไฟล์ {path} ได้: {e}", file=sys.stderr)
    return None

def get_api_key():
    """Gets the Gemini API key from environment, .env file, or user input."""
    # 1. Try environment variable
    api_key = os.environ.get("GEMINI_API_KEY")
    if api_key:
        return api_key

    # 2. Try .env file
    api_key = load_api_key_from_env_file()
    if api_key:
        return api_key

    # 3. Prompt user
    print("🔑 ไม่พบ GEMINI_API_KEY ใน Environment หรือไฟล์ .env")
    try:
        api_key = input("กรุณาป้อน GEMINI_API_KEY ของคุณ: ").strip()
        if api_key:
            return api_key
    except KeyboardInterrupt:
        print("\nยกเลิกการทำงาน")
        sys.exit(1)

    return None

def review_code_with_gemini(diff_content, api_key, model=DEFAULT_MODEL):
    """Sends the diff to the Gemini API and returns the review markdown."""
    print(f"🤖 กำลังส่งโค้ดไปรีวิวด้วยโมเดล {model} ...")
    
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
    
    prompt = (
        "คุณคือผู้เชี่ยวชาญด้านการรีวิวโค้ด (Senior Software Engineer/Code Reviewer) "
        "โปรดตรวจสอบการเปลี่ยนแปลงของโค้ด (Git Diff) ต่อไปนี้อย่างละเอียด และจัดทำรายงานการรีวิวเป็นภาษาไทย "
        "โดยเน้นในประเด็นต่างๆ ดังนี้:\n"
        "1. บั๊กหรือข้อผิดพลาดที่อาจเกิดขึ้น (Potential Bugs & Logic Errors)\n"
        "2. ประสิทธิภาพการทำงาน (Performance Optimization)\n"
        "3. ความปลอดภัยของโค้ด (Security Vulnerabilities)\n"
        "4. ความสะอาดของโค้ดและแนวทางปฏิบัติที่ดีที่สุด (Code Readability, Best Practices โดยเฉพาะหากเป็นภาษา Dart/Flutter)\n"
        "5. ข้อเสนอแนะหรือแนวทางแก้ไขเพิ่มเติม (Suggestions with code examples if helpful)\n\n"
        "กรุณาจัดรูปแบบคำตอบให้สวยงามด้วย Markdown มีหัวข้อที่ชัดเจน และเขียนให้อ่านง่ายสำหรับนักพัฒนาคนอื่นๆ\n\n"
        "นี่คือโค้ดที่มีการเปลี่ยนแปลง (Git Diff):\n"
        f"```diff\n{diff_content}\n```"
    )

    payload = {
        "contents": [
            {
                "parts": [
                    {
                        "text": prompt
                    }
                ]
            }
        ]
    }

    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST"
    )

    try:
        with urllib.request.urlopen(req) as response:
            res_data = json.loads(response.read().decode("utf-8"))
            
            # Extract content from response structure
            try:
                review_text = res_data["candidates"][0]["content"]["parts"][0]["text"]
                return review_text
            except (KeyError, IndexError) as e:
                print("❌ รูปแบบ Response จาก API ไม่ถูกต้อง:", e, file=sys.stderr)
                print(json.dumps(res_data, indent=2), file=sys.stderr)
                return None

    except urllib.error.HTTPError as e:
        print(f"❌ API เกิดข้อผิดพลาด (HTTP {e.code}): {e.reason}", file=sys.stderr)
        try:
            error_body = json.loads(e.read().decode("utf-8"))
            print(json.dumps(error_body, indent=2), file=sys.stderr)
        except Exception:
            pass
        return None
    except Exception as e:
        print(f"❌ เกิดข้อผิดพลาดในการเชื่อมต่อ API: {e}", file=sys.stderr)
        return None

def get_github_pr_diff(repo, pr_number, token):
    """Retrieves the git diff of a Pull Request from GitHub API."""
    url = f"https://api.github.com/repos/{repo}/pulls/{pr_number}"
    req = urllib.request.Request(url)
    req.add_header("Accept", "application/vnd.github.v3.diff")
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("User-Agent", "gemini-code-reviewer-action")
    try:
        with urllib.request.urlopen(req) as response:
            return response.read().decode("utf-8", errors="replace")
    except Exception as e:
        print(f"❌ ไม่สามารถดึง PR Diff จาก GitHub API ได้: {e}", file=sys.stderr)
        return None

def post_github_comment(repo, pr_number, comment, token):
    """Posts a comment to a GitHub Pull Request."""
    url = f"https://api.github.com/repos/{repo}/issues/{pr_number}/comments"
    payload = {"body": comment}
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Accept": "application/vnd.github.v3+json",
            "Authorization": f"Bearer {token}",
            "User-Agent": "gemini-code-reviewer-action",
            "Content-Type": "application/json"
        },
        method="POST"
    )
    try:
        with urllib.request.urlopen(req) as response:
            print("🎉 โพสต์ผลการรีวิวลงใน GitHub Pull Request เรียบร้อยแล้ว!")
            return True
    except Exception as e:
        print(f"❌ ไม่สามารถโพสต์ผลการรีวิลงใน GitHub ได้: {e}", file=sys.stderr)
        return False

def get_github_commit_diff(repo, commit_sha, token):
    """Retrieves the git diff of a specific commit from GitHub API."""
    url = f"https://api.github.com/repos/{repo}/commits/{commit_sha}"
    req = urllib.request.Request(url)
    req.add_header("Accept", "application/vnd.github.v3.diff")
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("User-Agent", "gemini-code-reviewer-action")
    try:
        with urllib.request.urlopen(req) as response:
            return response.read().decode("utf-8", errors="replace")
    except Exception as e:
        print(f"❌ ไม่สามารถดึง Commit Diff จาก GitHub API ได้: {e}", file=sys.stderr)
        return None

def post_github_commit_comment(repo, commit_sha, comment, token):
    """Posts a comment to a GitHub commit."""
    url = f"https://api.github.com/repos/{repo}/commits/{commit_sha}/comments"
    payload = {"body": comment}
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Accept": "application/vnd.github.v3+json",
            "Authorization": f"Bearer {token}",
            "User-Agent": "gemini-code-reviewer-action",
            "Content-Type": "application/json"
        },
        method="POST"
    )
    try:
        with urllib.request.urlopen(req) as response:
            print(f"🎉 โพสต์ผลการรีวิวลงใน GitHub Commit ({commit_sha}) เรียบร้อยแล้ว!")
            return True
    except Exception as e:
        print(f"❌ ไม่สามารถโพสต์ผลการรีวิลงใน GitHub Commit ได้: {e}", file=sys.stderr)
        return False

def handle_github_actions(model):
    """Handles the code review execution when running inside GitHub Actions."""
    event_name = os.environ.get("GITHUB_EVENT_NAME")
    event_path = os.environ.get("GITHUB_EVENT_PATH")
    repo = os.environ.get("GITHUB_REPOSITORY")
    commit_sha = os.environ.get("GITHUB_SHA")

    if not event_path or not repo:
        print("❌ ข้อผิดพลาด: ไม่พบตัวแปรสภาพแวดล้อมที่จำเป็นสำหรับ GitHub Actions", file=sys.stderr)
        sys.exit(1)
        
    github_token = os.environ.get("GITHUB_TOKEN")
    if not github_token:
        print("❌ ข้อผิดพลาด: ไม่พบ GITHUB_TOKEN ใน Environment", file=sys.stderr)
        sys.exit(1)

    gemini_api_key = os.environ.get("GEMINI_API_KEY")
    if not gemini_api_key:
        print("❌ ข้อผิดพลาด: ไม่พบ GEMINI_API_KEY ใน Environment", file=sys.stderr)
        sys.exit(1)

    try:
        with open(event_path, "r", encoding="utf-8") as f:
            event_data = json.load(f)
    except Exception as e:
        print(f"❌ ไม่สามารถอ่าน GitHub Event file: {e}", file=sys.stderr)
        sys.exit(1)

    pr_number = event_data.get("number")

    # กรณีเป็น Event Pull Request
    if event_name == "pull_request" or pr_number is not None:
        print(f"📦 ตรวจพบ Pull Request #{pr_number} สำหรับ Repository: {repo}")
        
        # 1. Get PR Diff
        diff_content = get_github_pr_diff(repo, pr_number, github_token)
        if not diff_content or not diff_content.strip():
            print("ℹ️ ดึงข้อมูล Git Diff สำเร็จ แต่อาจไม่มีการเปลี่ยนแปลงของโค้ด")
            return

        diff_lines = diff_content.count("\n")
        print(f"📝 ขนาด Git Diff: ประมาณ {diff_lines} บรรทัด")

        # 2. Get Code Review from Gemini
        review_result = review_code_with_gemini(diff_content, gemini_api_key, model=model)
        if not review_result:
            print("❌ การรีวิวโค้ดด้วย Gemini ล้มเหลว")
            sys.exit(1)

        # 3. Post comment to GitHub PR
        post_github_comment(repo, pr_number, review_result, github_token)

    # กรณีเป็น Event Push (เช่น commit โดยตรงลงใน branchหลัก)
    elif event_name == "push" or commit_sha is not None:
        print(f"📦 ตรวจพบ Push Event สำหรับ Commit: {commit_sha} ใน Repository: {repo}")

        # 1. Get Commit Diff
        diff_content = get_github_commit_diff(repo, commit_sha, github_token)
        if not diff_content or not diff_content.strip():
            print("ℹ️ ดึงข้อมูล Git Diff สำเร็จ แต่อาจไม่มีการเปลี่ยนแปลงของโค้ดสำหรับ Commit นี้")
            return

        diff_lines = diff_content.count("\n")
        print(f"📝 ขนาด Git Diff: ประมาณ {diff_lines} บรรทัด")

        # 2. Get Code Review from Gemini
        review_result = review_code_with_gemini(diff_content, gemini_api_key, model=model)
        if not review_result:
            print("❌ การรีวิวโค้ดด้วย Gemini ล้มเหลว")
            sys.exit(1)

        # 3. Post comment to GitHub Commit
        post_github_commit_comment(repo, commit_sha, review_result, github_token)
    else:
        print(f"❌ ข้อผิดพลาด: ไม่รองรับการทำงานกับ Event: {event_name}", file=sys.stderr)
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description="สคริปต์รีวิว Code ก่อนขึ้น GitHub ด้วย Gemini API")
    parser.add_argument("--staged", "-s", action="store_true", help="รีวิวเฉพาะไฟล์ที่ staged แล้ว (git add)")
    parser.add_argument("--branch", "-b", type=str, default=None, help="รีวิวความต่างเมื่อเทียบกับ branch ที่กำหนด (เช่น main)")
    parser.add_argument("--model", "-m", type=str, default=DEFAULT_MODEL, help=f"กำหนดโมเดล Gemini (ค่าเริ่มต้น: {DEFAULT_MODEL})")
    parser.add_argument("--output", "-o", type=str, default=REVIEW_FILE, help=f"กำหนดชื่อไฟล์บันทึกผลการรีวิว (ค่าเริ่มต้น: {REVIEW_FILE})")
    parser.add_argument("--github", "-g", action="store_true", help="รันในโหมด GitHub Actions (รีวิว Pull Request และโพสต์คอมเมนต์)")
    args = parser.parse_args()

    # If GitHub mode is enabled, divert flow
    if args.github:
        handle_github_actions(args.model)
        return

    # 1. Extract diff
    diff_content = get_git_diff(staged=args.staged, branch=args.branch)
    if not diff_content:
        print("ℹ️ ไม่พบความเปลี่ยนแปลงของโค้ดที่จะทำการรีวิว (Git diff ว่างเปล่า)")
        print("กรุณาตรวจสอบว่ามีไฟล์ที่แก้ไข หรือใช้ตัวเลือกที่ถูกต้อง เช่น --staged หรือ --branch main")
        return

    # Warm prompt for the user about diff size
    diff_lines = diff_content.count("\n")
    print(f"📝 ตรวจพบการแก้ไขโค้ดทั้งหมดประมาณ {diff_lines} บรรทัด")

    # 2. Get API key
    api_key = get_api_key()
    if not api_key:
        print("❌ เกิดข้อผิดพลาด: ไม่พบ API Key สคริปต์หยุดทำงาน", file=sys.stderr)
        sys.exit(1)

    # 3. Call API
    review_result = review_code_with_gemini(diff_content, api_key, model=args.model)
    if not review_result:
        print("❌ ไม่สามารถดึงรายงานการรีวิวได้")
        sys.exit(1)

    # 4. Save and Output
    try:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(review_result)
        print(f"\n🎉 บันทึกรายงานการรีวิวเรียบร้อยที่: {args.output}\n")
    except Exception as e:
        print(f"⚠️ ไม่สามารถเขียนไฟล์ผลลัพธ์ได้: {e}", file=sys.stderr)

    # Print to console
    print("-" * 60)
    print("📢 สรุปผลการรีวิวจาก Gemini:")
    print("-" * 60)
    print(review_result)
    print("-" * 60)

if __name__ == "__main__":
    main()
