import from web.landing.Hero { Hero }
import from web.landing.StatsBand { StatsBand }
import from web.landing.WasmGame { WasmGame }
import from web.landing.MobileShowcase { MobileShowcase }
import from web.landing.WhyJac { WhyJac }
import from web.landing.Showcase { Showcase }
import from web.landing.Capabilities { Capabilities }
import from web.landing.OneBinary { OneBinary }
import from web.landing.Agents { Agents }
import from web.landing.BookSection { BookSection }
import from web.landing.ExplorerFinale { ExplorerFinale }
import from web.ui.SectionRail { SectionRail }

glob HOME_NAV: list[dict] = [
         {"id": "h-arena", "label": "arena"},
         {"id": "h-mobile", "label": "mobile"},
         {"id": "h-why", "label": "why jac"},
         {"id": "h-showcase", "label": "showcase"},
         {"id": "h-capabilities", "label": "capabilities"},
         {"id": "h-onebinary", "label": "one binary"},
         {"id": "h-agents", "label": "agents"},
         {"id": "h-book", "label": "the book"},
         {"id": "h-explore", "label": "explore"},

     ];

def:pub page -> JsxPage {
    return
        <>
            <SectionRail items={HOME_NAV}/>
            <Hero/>
            <StatsBand/>
            <div id="h-arena" className="scroll-mt-24">
                <WasmGame/>
            </div>
            <div id="h-mobile" className="scroll-mt-24">
                <MobileShowcase/>
            </div>
            <div id="h-why" className="scroll-mt-24">
                <WhyJac/>
            </div>
            <div id="h-showcase" className="scroll-mt-24">
                <Showcase/>
            </div>
            <div id="h-capabilities" className="scroll-mt-24">
                <Capabilities/>
            </div>
            <div id="h-onebinary" className="scroll-mt-24">
                <OneBinary/>
            </div>
            <div id="h-agents" className="scroll-mt-24">
                <Agents/>
            </div>
            <div id="h-book" className="scroll-mt-24">
                <BookSection/>
            </div>
            <div id="h-explore" className="scroll-mt-24">
                <ExplorerFinale/>
            </div>
        </>;
}
