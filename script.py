import os
import re

lib_dir = r"c:\Users\prath\Documents\GitHub\sahaya\lib"

# To avoid replacing inside comments or other things, it's safer but we'll try this
# Also, ignore files that have TextScaleFactor etc. We checked, they don't.

for root, dirs, files in os.walk(lib_dir):
    for f in files:
        if f == 'translator.dart':
            continue
        if f.endswith('.dart'):
            filepath = os.path.join(root, f)
            with open(filepath, 'r', encoding='utf-8') as file:
                content = file.read()
            
            # Check if there is a 'Text(' not preceded by a word character
            if re.search(r'(?<![A-Za-z0-9_])Text\(', content):
                # We need to import the translator.dart file. Let's calculate the relative path based on the depth
                rel_path = os.path.relpath(os.path.join(lib_dir, 'utils', 'translator.dart'), root).replace('\\\\', '/').replace('\\', '/')
                import_statement = f"import '{rel_path}';\n"
                
                # Replace
                new_content = re.sub(r'(?<![A-Za-z0-9_])Text\(', 'T(', content)
                
                if new_content != content:
                    # Prepend import if not there
                    if 'translator.dart' not in new_content:
                        # Find last import
                        import_matches = list(re.finditer(r'^import .*;$', new_content, re.MULTILINE))
                        if import_matches:
                            last_import_index = import_matches[-1].end()
                            new_content = new_content[:last_import_index] + '\n' + import_statement + new_content[last_import_index:]
                        else:
                            new_content = import_statement + new_content
                        
                    with open(filepath, 'w', encoding='utf-8') as file:
                        file.write(new_content)
                    print(f'Updated {filepath}')
