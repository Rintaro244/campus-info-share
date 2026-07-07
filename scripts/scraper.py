import requests
from bs4 import BeautifulSoup
import time
import re  # ★追加：JavaScriptの中から特定のパターンを探し出す道具

# ==========================================
# 1. 基本設定（URLなど）
# ==========================================
LIST_URL = "https://syllabus.sic.shibaura-it.ac.jp/syllabus/2026/MatrixLL01.html" 
FACULTY_NAME = "工学部"
COURSE_NAME = "情報工学コース"

HEADERS = {"Accept-Language": "ja,ja-JP;q=0.9,en;q=0.8"}
COOKIES = {"lang": "ja", "locale": "ja", "language": "ja", "syllabo_lang": "ja"}

def get_syllabus_data():
    print("🔍 1段階目: 一覧ページから授業データと「本当の隠しURL」を取得中...")
    res = requests.get(LIST_URL, headers=HEADERS, cookies=COOKIES)
    res.encoding = res.apparent_encoding
    soup = BeautifulSoup(res.text, 'html.parser')

    # ページ内に書かれているJavaScriptのコードをすべて繋げて1つのテキストにしておく
    script_texts = "".join([s.text for s in soup.find_all('script') if s.text])

    courses = []
    
    for tr in soup.find_all('tr', class_='subject'):
        tds = tr.find_all('td')
        if len(tds) >= 4:
            course_id = tds[2].text.strip()
            title = tds[3].text.strip()
            
            tr_id = tr.get('id', '')
            internal_id = ""
            if tr_id.startswith('s') and '-' in tr_id:
                internal_id = tr_id.split('-')[0].replace('s', '')
            
            if internal_id:
                # 【最大の魔法】JavaScriptの中から「161469, 'Z1510100', 153403」のような並びを探し、最後の本物IDだけを抜き出す！
                match = re.search(fr"{internal_id},\s*'{course_id}',\s*(\d+)", script_texts)
                
                if match:
                    real_id = match.group(1) # これが「153403」などの本物のID！
                    detail_url = f"https://syllabus.sic.shibaura-it.ac.jp/syllabus/2026/ko1/{real_id}.html?y=2026&g=LL0"
                    
                    courses.append({
                        'id': course_id,
                        'title': title,
                        'url': detail_url
                    })
                
    print(f"✅ {len(courses)} 件の授業と「本物のURL」を発見しました！\n")
    return courses

def scrape_professors(courses):
    print("🚀 2段階目: 詳細ページを巡回して「担当教員名」を抜き出します...")
    dart_objects = []
    
    for i, course in enumerate(courses):
        # =========================================================
        # ⚠️ 安全装置：テスト用に「最初の3件」でストップします。
        # 本番データを一気に作る時は、下の2行（ifとbreak）を消してください！
        # =========================================================
            
        print(f"[{i+1}/{len(courses)}] 取得中: {course['title']} ...", end=" ")
        
        try:
            res = requests.get(course['url'], headers=HEADERS, cookies=COOKIES)
            res.encoding = res.apparent_encoding
            detail_soup = BeautifulSoup(res.text, 'html.parser')
            
            professor = "不明"
            
            # class="teacher" のtdタグから教員名を取得
            td_teacher = detail_soup.find('td', class_='teacher')
            if td_teacher:
                professor = td_teacher.text.strip().replace('\n', ' ').replace('\r', '').replace(' ', ' ')
            
            print(f"教員: {professor}")
            
        except Exception as e:
            print(f"❌ エラー")
            professor = "取得エラー"

        dart_code = f"""  Lecture(
    id: '{course['id']}',
    faculty: '{FACULTY_NAME}',
    course: '{COURSE_NAME}',
    title: '{course['title']}',
    professor: '{professor}',
    review: '',
    difficultyRating: 0,
    taskAmountRating: 0,
    paceRating: 0,
  ),"""
        dart_objects.append(dart_code)
        
        # 大学のサーバーに負荷をかけないための1秒待機
        time.sleep(1) 
        
    return dart_objects

def write_to_dart_file(dart_objects):
    with open('dummy_data.dart', 'w', encoding='utf-8') as f:
        f.write("import '../models/lecture.dart';\n\n")
        f.write("final List<Lecture> allLecturesMaster = [\n")
        for obj in dart_objects:
            f.write(obj + "\n")
        f.write("];\n")
    print("\n🎉 完了！ dummy_data.dart に完全なデータを書き出しました！")

if __name__ == "__main__":
    course_list = get_syllabus_data()
    if course_list:
        objects = scrape_professors(course_list)
        write_to_dart_file(objects)