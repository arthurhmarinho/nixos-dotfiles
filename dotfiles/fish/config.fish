# ~/.config/fish/config.fish
if status is-interactive
    # Ao abrir o terminal: fastfetch no lugar da saudação padrão
    function fish_greeting
        fastfetch
    end

    # Cores do fish na paleta vermelha
    set -g fish_color_command e2d2c0
    set -g fish_color_param b8aaa0
    set -g fish_color_quote e5a04b
    set -g fish_color_error e0533d
    set -g fish_color_autosuggestion 5a4f4c
    set -g fish_color_comment 5a4f4c
    set -g fish_color_operator e0533d
    set -g fish_color_redirection e0533d
    set -g fish_color_valid_path --underline
    set -g fish_pager_color_prefix e0533d
    set -g fish_pager_color_progress 8a7f7c
end
