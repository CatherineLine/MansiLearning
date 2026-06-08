import os
from pathlib import Path

def merge_dart_files(root_dir, output_file="all_code.txt"):
    """Собирает все .dart файлы в один текстовый файл"""

    with open(output_file, 'w', encoding='utf-8') as outfile:
        # Проходим по всем файлам в директории
        for file_path in Path(root_dir).rglob("*.dart"):
            try:
                # Записываем заголовок с именем файла
                outfile.write(f"\n{'='*80}\n")
                outfile.write(f"Файл: {file_path.relative_to(root_dir)}\n")
                outfile.write(f"{'='*80}\n\n")

                # Записываем содержимое файла
                with open(file_path, 'r', encoding='utf-8') as infile:
                    outfile.write(infile.read())

                outfile.write("\n\n")
                print(f"✓ Добавлен: {file_path}")
            except Exception as e:
                print(f"✗ Ошибка {file_path}: {e}")

    print(f"\n✅ Готово! Файл сохранён: {output_file}")

# Запуск
if __name__ == "__main__":
    # Укажите путь к папке с проектом
    project_path = ""  # текущая папка
    merge_dart_files(project_path, "all_dart_code.txt")