<?php

/*
    What the chat and the board will not carry.

    Two lists doing two different jobs, and they are deliberately not merged.

    Profanity is masked. Somebody swearing in a message is being rude, not
    defrauding anybody, and refusing to deliver the message only means they
    send it again with a space in the middle. Masking lets the conversation
    carry on and takes the word out of it.

    Contact details and "let us talk somewhere else" are refused outright.
    That is the loophole: two people introduced by KAYA move to Messenger,
    arrange every later job there, and the platform that matched them never
    sees another one. Unlocking somebody's contact details is a thing you buy
    here, so handing them over in a free message is also the paid feature
    being given away.

    Everything is matched against a normalised copy of the message - see
    MessageFilter - so a word list survives jejemon spelling, leetspeak and
    padding. Write the entries here in plain lowercase; the normaliser handles
    the rest.
*/

return [

    /*
        Filipino first, because that is what the app is written in.

        Based on the maintained MIT-licensed Filipino bad words list at
        github.com/jromest/filipino-badwords-list, with the Bisaya words a
        Pangasinan user base actually uses, and the English set that any
        filter is expected to carry.

        Multi-word entries are matched across adjacent words, so "putang ina"
        is caught whether or not it is written as one word.
    */
    'profanity' => [
        // Tagalog
        'amputa', 'animal ka', 'bilat', 'bobo', 'buang', 'bwisit', 'buwisit',
        'demonyo ka', 'engot', 'gaga', 'gago', 'gunggong', 'hayop ka',
        'hinayupak', 'hudas', 'inutil', 'kantot', 'kiki', 'kingina',
        'kinginamo', 'kupal', 'lecheng', 'lintik', 'pakshet', 'pakyu',
        'peste', 'pesteng yawa', 'pisti', 'pota', 'potangina', 'pucha',
        'punyeta', 'puta', 'putangina', 'putang ina', 'putaragis', 'putragis',
        'salot', 'siraulo', 'tae', 'tanga', 'tangina', 'tangina mo',
        'tarantado', 'tite', 'tuta', 'ulol', 'ungas', 'walanghiya', 'yawa',

        // English
        'asshole', 'bastard', 'bitch', 'cunt', 'dickhead', 'faggot', 'fuck',
        'fucking', 'motherfucker', 'nigga', 'nigger', 'pussy', 'retard',
        'shit', 'slut', 'whore',
    ],

    /*
        Apps people move the conversation to.

        Payment apps are deliberately absent. KAYA never holds anybody's job
        payment - that settles between the two of them off the platform, and
        it is meant to - so a worker saying "GCash na lang po" is doing the
        normal thing and must not be stopped.

        The misspellings are not typos. They are how a word list gets beaten.
    */
    'off_platform_apps' => [
        'messenger', 'mesenger', 'messanger', 'meseng', 'messeng',
        'facebook', 'fb', 'fbmessenger', 'fesbuk', 'peysbuk',
        'viber', 'bayber', 'vyber',
        'telegram', 'teleg', 'telgram',
        'whatsapp', 'wasap', 'watsap', 'hwatsap',
        'instagram', 'insta', 'igmo',
        'tiktok', 'tikok',
        'snapchat', 'discord', 'skype', 'wechat', 'kakao',
    ],

    /*
        The colour code.

        Facebook is "the blue app", and the same trick names every other one
        without typing its name. Rather than keep a table of which colour
        means which app - which would mean guessing, and would be wrong the
        week somebody picks a new colour - any colour placed next to "app" is
        treated as what it is: a name chosen to get past a filter.
    */
    'colours' => [
        'blue', 'yellow', 'green', 'red', 'orange', 'purple', 'pink', 'violet',
        'asul', 'dilaw', 'berde', 'pula', 'kahel', 'lila', 'ube',
    ],

    /*
        "Let us talk somewhere else", in the words people actually use.

        Written without punctuation and in the order they are said. The
        normaliser flattens spacing and jejemon padding before matching, so
        "txt mo nlng ako" reaches this list as "text mo na lang ako" only
        where the shortcut is listed too - which is why both spellings appear.
    */
    'evasion_phrases' => [
        'add mo ako', 'add mo ko', 'add kita', 'add mo me',
        'pm mo ako', 'pm mo ko', 'pm kita', 'pm na lang', 'pm nalang',
        'text mo ako', 'text mo ko', 'text mo na lang', 'text mo nalang',
        'txt mo ako', 'txt mo ko', 'txt mo na lang', 'txt mo nalang',
        'tawagan mo ako', 'tawagan mo ko', 'tawag ka na lang',
        'message mo ako sa', 'chat mo ako sa', 'chat na lang tayo sa',
        'sa labas na lang', 'sa labas tayo', 'labas na lang tayo',
        'labas tayo sa app', 'lbs na lang',
        'wag na dito', 'wag dito sa app', 'wag na sa app', 'huwag na dito',
        'wag na tayo dito', 'hindi na dito',
        'direct na lang', 'direkta na lang', 'direct message na lang',
        'sa fb na lang', 'sa fb nalang', 'fb na lang', 'fb nalang',
        'number mo', 'numero mo', 'num mo', 'nmbr mo', 'nmber mo',
        'cp number', 'cp no', 'cp num', 'cp nmbr',
        'cellphone number', 'cellphone no', 'contact number', 'contact no',
        'pahingi number', 'pahingi ng number', 'pa number', 'pasend number',
        'pakisend number', 'ano number mo', 'ano cp mo',
    ],

    /*
        Jejemon and leetspeak, mapped before anything is matched.

        Left of the arrow is what gets typed, right is what it means. Only
        substitutions that are unambiguous in this context are here - 'p' for
        'f' is real jejemon but would turn ordinary words into nonsense.
    */
    'substitutions' => [
        '0' => 'o', '1' => 'i', '3' => 'e', '4' => 'a', '5' => 's',
        '7' => 't', '8' => 'b', '@' => 'a', '$' => 's', '!' => 'i',
    ],

    /*
        Shortcut spellings expanded before phrase matching, so one phrase in
        the list above covers every way it is typed.
    */
    'expansions' => [
        'txt' => 'text', 'msg' => 'message', 'msge' => 'message',
        'nmbr' => 'number', 'nmber' => 'number', 'numbr' => 'number',
        'nlng' => 'na lang', 'nalang' => 'na lang', 'nlang' => 'na lang',
        'lng' => 'lang', 'lbs' => 'labas', 'dto' => 'dito', 'd2' => 'dito',
        'wg' => 'wag', 'hwag' => 'wag', 'huwag' => 'wag',
        'ako2' => 'ako', 'aq' => 'ako', 'kta' => 'kita', 'mo2' => 'mo',
        'cfone' => 'cellphone', 'cellfone' => 'cellphone',
        'fon' => 'phone', 'pone' => 'phone',
    ],
];
