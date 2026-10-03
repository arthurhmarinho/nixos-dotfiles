# ~/.config/fish/config.fish
if status is-interactive
    # Ao abrir o terminal: fastfetch no lugar da saudação padrão
    function fish_greeting
        fastfetch
    end

    # Cores do fish: geradas pelo wallust a partir do wallpaper
    test -f ~/.cache/wallust/colors.fish; and source ~/.cache/wallust/colors.fish
end
