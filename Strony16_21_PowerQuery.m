// ============================================================
// Power Query (jezyk M) — transformacja danych z pliku CSV
// wygenerowanego z OCR pliku Strony16_21.pdf
// Uzycie w Excelu: Dane > Pobierz dane > Z pliku > Z pliku CSV
//   (albo Zapytanie puste > Edytor zaawansowany i wklej ponizszy kod)
// Zmien sciezke Source na wlasna lokalizacje pliku CSV.
// ============================================================
let
    // 1) Wczytanie pliku zrodlowego (separator srednik, kodowanie UTF-8, 65001)
    Source = Csv.Document(
        File.Contents("C:\!bat\Claude\kurscc\Strony16_21_dane.csv"),
        [Delimiter=";", Columns=17, Encoding=65001, QuoteStyle=QuoteStyle.None]
    ),
    // 2) Pierwszy wiersz jako naglowki
    Naglowki = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),
    // 3) Typy kolumn (miesiace i Suma jako liczby calkowite)
    Miesiace = {"sty","lut","mar","kwi","maj","cze","lip","sie","wrz","paz","lis","gru"},
    Typy = Table.TransformColumnTypes(
        Naglowki,
        {{"Nr czesci", Int64.Type}, {"Oddzial", type text}, {"Adres dostawy", type text},
         {"Rok", Int64.Type}, {"Suma", Int64.Type}}
        & List.Transform(Miesiace, each {_, Int64.Type})
    ),
    // 4) UNPIVOT: zamiana 12 kolumn miesiecy na wiersze (Miesiac / Ilosc)
    //    (puste komorki = brak dostawy w danym miesiacu -> pomijane)
    Unpivot = Table.UnpivotOtherColumns(
        Table.RemoveColumns(Typy, {"Suma"}),
        {"Nr czesci","Oddzial","Adres dostawy","Rok"}, "Miesiac", "Ilosc"
    ),
    // 5) Numer miesiaca + kolumna Data (pierwszy dzien miesiaca)
    MapMies = [sty=1,lut=2,mar=3,kwi=4,maj=5,cze=6,lip=7,sie=8,wrz=9,paz=10,lis=11,gru=12],
    NrMies = Table.AddColumn(Unpivot, "Nr miesiaca", each Record.Field(MapMies, [Miesiac]), Int64.Type),
    ZData = Table.AddColumn(NrMies, "Data", each #date([Rok], [Nr miesiaca], 1), type date),
    // 6) Porzadkowanie
    Sort = Table.Sort(ZData, {{"Nr czesci", Order.Ascending}, {"Adres dostawy", Order.Ascending},
                              {"Rok", Order.Ascending}, {"Nr miesiaca", Order.Ascending}}),
    Wynik = Table.ReorderColumns(Sort,
        {"Nr czesci","Oddzial","Adres dostawy","Rok","Nr miesiaca","Miesiac","Data","Ilosc"})
in
    Wynik
