> Arbeitsdatei: Hier ergänzen, wenn fertig wird der Inhalt in die Shiny-App übernommen.
> Stand: spiegelt den Inhalt des Tabs "Metadaten & Methodik" der App (BerlinLakeAccess_ShinyApp.R, Zeilen 400-505).

# Metadaten

## Autorin

Ivonne Giske

## Titel

Berliner Badestellen - Thematische Karte zur Erreichbarkeit

## Entstehungskontext

Die Anwendung wurde im Rahmen des Moduls Thematische Internetkartographie im Studiengang Geoinformation (MSc) an der Berliner Hochschule für Technik (BHT) im Sommersemester 2026 entwickelt. Aufgabe war die Erstellung einer interaktiven Webkarte zu einem selbst gewählten Thema.

## Hintergrund & Fragestellung

Heiße Sommer erhöhen den Bedarf an schnell erreichbaren Möglichkeiten zur Abkühlung. Initiativen wie Flussbad Berlin machen mit Badeaktionen in der Spree auf das Potenzial innerstädtischer Bademöglichkeiten und den Bedarf an weiteren Badestellen aufmerksam. Auch temporäre Projekte wie ein Schwimmbecken vor der Volksbühne zeigen den Diskussionsbedarf um zusätzliche Bademöglichkeiten in zentralen Stadtgebieten.

Es stellt sich die Frage nach der Erreichbarkeit von Badestellen im vergleichsweise wasserreichen Berlin. Welche Ortsteile oder Bezirke schneiden besonders gut ab? Wo befinden sich „Badewüsten“? Gibt es Zusammenhänge mit der Verteilung dicht besiedelter Bereiche?

Die Anwendung veranschaulicht die räumliche Verteilung der 39 offiziell ausgewiesenen und nach der EU-Badegewässerrichtlinie überwachten Badestellen Berlins und deren Erreichbarkeit auf Grundlage von Einwohnerdichtedaten. Untersucht werden die Mobilitätsmodi Fahrrad und zu Fuß für drei Anreisezeiten von 5, 10 und 20 Minuten. Zusätzlich werden die Badestellen mithilfe eines Gravity-Modells gerankt (siehe Methodik). Das Ranking dient dazu, den potenziellen „Druck“ auf die einzelnen Badestellen abzubilden. Die Ergebnisse werden in einer interaktiven Karte dargestellt.

## Ziel & Ausblick

Die Anwendung soll eine datenbasierte Betrachtung des Themas ermöglichen und damit zur Diskussion über eine gerechte und bedarfsorientierte Verteilung von Bademöglichkeiten in Berlin beitragen. Die Ergebnisse können als Grundlage für weiterführende Untersuchungen dienen, etwa zur Frage, wie die Erreichbarkeit mit sozioökonomischen und demografischen Merkmalen der Bevölkerung zusammenhängt.

## Datenquellen

**Badestellen**
- Geoportal Berlin: Badegewässerqualität, Layer aa_badestellen (WFS). Verantwortliche Stelle: Landesamt für Gesundheit und Soziales Berlin. Lizenz: CC BY 4.0. Abruf: 07.09.2026. [Metadaten-Link](https://gdi.berlin.de/geonetwork/srv/ger/catalog.search#/metadata/0b0218f9-5d32-4dba-9cc6-169768af2027)

**Einwohnerdichte**
- Geoportal Berlin: Einwohnerdichte 2025 (Umweltatlas), Layer ua_einwohnerdichte_2025 (WFS). Datengeber: Amt für Statistik Berlin-Brandenburg. Lizenz: CC BY 3.0 DE. Abgerufen am 07.09.2026. [Metadaten-Link](https://gdi.berlin.de/geonetwork/srv/ger/catalog.search#/metadata/69b82abc-377e-44d2-b598-c8feb8643e95)
- Datenstand 2025; Summe der Einwohnerzahlen der verwendeten Einwohnerdichte-Flächen: 3.913.490 EW (3,9 Mio.)

**Bezirke, Ortsteile**
- Geoportal Berlin: ALKIS Bezirke, Ortsteile Berlin (WFS). Datengeber: Senatsverwaltung für Stadtentwicklung, Bauen und Wohnen Berlin. Lizenz: Datenlizenz Deutschland – Zero – Version 2.0. Abruf: 07.09.2026. [Metadaten-Link](https://gdi.berlin.de/geonetwork/srv/ger/catalog.search#/metadata/0a7c53a5-b29d-3f45-9734-1c811045e6c2)

**Erreichbarkeitszonen (Isochronen)**
- openrouteservice des Heidelberg Institute for Geoinformation Technology (HeiGIT), mit API-Key. Abruf: 07.09.2026. [Webseite](https://heigit.org/de/)

**Wasserflächen**
- OpenStreetMap, Overpass-Abfrage in QGIS, anschließend manuell selektiert. Abruf: 07.09.2026.

## Basemaps und Anbieter

Stadia Maps / CARTO / OpenMapTiles / OpenStreetMap.

---

# Umsetzung & Code

## R, R-Pakete und Versionen

Die Anwendung wurde als Shiny-App mit tmap und tmap.mapgl in RStudio entwickelt. Die Veröffentlichung erfolgte über RPubs.

R Version 4.5.1 (2025-06-13)

shiny 1.13.0, sf 1.1.0, dplyr 1.2.1, tmap 4.4, tmap.mapgl 0.3, DT 0.34.0, stars 0.7.2.

Für das Hilfsdiagramm im Badestellen-Tab zusätzlich: tidyr 1.3.2, ggplot2 4.0.2.

## Repository

github-link folgt

## Hinweis auf KI-Unterstützung

Konzeption, Fragestellung, Auswahl und Durchführung der Analyse sowie die fachlichen und methodischen Entscheidungen wurden eigenständig entwickelt und getroffen. ChatGPT wurde zur Überprüfung von R-Code bei der Datenaufbereitung eingesetzt. Für die Programmierung der Shiny-App wurde der Posit Assistant mit den Modellen deepseek-v4.1-flash, glm-5.3-flash und kimi-k2.7-code eingesetzt.

---

# Methodik

## Datenaufbereitung

> das Folgende muss ich nochmal überdenken, das meiste ist ja im Code ersichtlich

- Die Punktgeometrien einiger Badestellen wurden geringfügig lagekorrigiert, damit sie geeignete Zugangspunkte für die anschließende Erreichbarkeitsanalyse darstellen.
- Aus den über OpenStreetMap abgefragten Wasserflächen wurden zur Orientierung lediglich die wichtigsten Berliner Gewässer, insbesondere größere Seen und Fließgewässer, ausgewählt.
- Für die Analyse der Einwohnerdichte wurden zunächst Polygone ohne Einwohner*innen (EW) sowie als Gewässer klassifizierte Flächen ausgeschlossen. Zudem wurden 15 EW aufgrund einer unplausiblen Lage innerhalb von Gewässerflächen entfernt. Aus den verbleibenden Polygonen wurde jeweils ein innerhalb des Polygons liegender Repräsentativpunkt abgeleitet. Die im Ausgangsdatensatz enthaltenen Einwohnerzahlen wurden den entsprechenden Punkten zugeordnet. Für die Karte wurden daraus ein Rasterdatensatz mit der Auflösung 100x100 m erstellt.
- Die Erreichbarkeitszonen (Polygone) von 39 Badestellen wurden pro Mobilitätsmodus (Fahrrad, Fuß) zu 3 Zonen vereinigt: bis 5, 10 und 20 Minuten.

## Ranking der Badestellen mit dem Gravity-Modell

Das Ranking der Badestellen basiert auf einem Gravity-Modell, das berücksichtigt, wie gut die Badestellen von der Berliner Bevölkerung aus erreichbar sind und wie stark sie dabei mit anderen erreichbaren Badestellen konkurrieren.

Dazu wird für jeden Bevölkerungspunkt ermittelt, welche Badestellen innerhalb von 20 Minuten mit dem jeweiligen Mobilitätsmodus erreichbar sind. Je kürzer die Reisezeit, desto höher das Gewicht: 5 Minuten entsprechen einem Gewicht von 1, 10 Minuten von 0,5 und 20 Minuten von 0,25.

Erreicht ein Bevölkerungspunkt mehrere Badestellen, wird seine Einwohnerzahl auf diese Badestellen verteilt. Dabei erhält eine näher gelegene Badestelle einen größeren Anteil, während zusätzliche erreichbare Badestellen den Anteil der einzelnen Badestelle verringern.

Der Gravity-Score einer Badestelle ist die Summe der auf diese Weise zugeordneten Einwohner*innen. Er beschreibt damit eine modellbasierte, distanz- und konkurrenzgewichtete Bevölkerungsgröße – und nicht die tatsächliche oder erwartete Zahl der Badegäste.

Das Ranking ergibt sich aus dem Gravity-Score: Rang 1 hat den höchsten modellbasierten Wert.

Der Pressure Share zeigt, welcher Anteil der gesamten Berliner Bevölkerung einer Badestelle nach diesem Modell zugeordnet wird. Ein Wert von beispielsweise 10 % bedeutet daher, dass dem See nach dem Modell ein Anteil von 10 % der Berliner Bevölkerung zugerechnet wird.

## Grenzen der Analyse

Die Analyse berücksichtigt keine öffentlichen Verkehrsmittel wie S- und U-Bahn und bildet die tatsächliche Erreichbarkeit der Badestellen daher nur teilweise ab. Die Annahme, dass die Berliner Bevölkerung ausschließlich zu Fuß oder mit dem Fahrrad zu den Badestellen gelangt, stellt eine Vereinfachung dar. Zudem werden Personen, die von außerhalb Berlins anreisen, nicht berücksichtigt. Badestellen im angrenzenden Brandenburg bleiben ebenfalls unberücksichtigt, obwohl sie für Teile der Berliner Bevölkerung leichter erreichbar sein können als innerhalb Berlins gelegene Badestellen.

---

## Datum der letzten Aktualisierung

2026-09-13

> hier muss immer das aktuelle Datum rein, beim Speichern
