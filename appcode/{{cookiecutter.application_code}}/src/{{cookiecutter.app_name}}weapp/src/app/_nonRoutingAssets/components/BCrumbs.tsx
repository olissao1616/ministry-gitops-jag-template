'use client';

import React from "react";
import { usePathname } from "next/navigation";
import { Breadcrumbs, Link, Typography } from "@mui/material";
import { selectedAgencyAtom, selectedApplicationAtom } from "../store/atoms";
import { useAtom } from "jotai";
import { useRouter } from 'next/navigation';
import { URL_AGENCY_SELECT, URL_APPLICATION_SELECT, URL_MAINMENU, containerMenu } from "../types/const";

export default function BCrumbs() {
    const [selectedApplication, setSelectedApplication] = useAtom(selectedApplicationAtom);
    const [selectedAgency, setSelectedAgency] = useAtom(selectedAgencyAtom);

    const router = useRouter();
    const paths = usePathname();
    const atMainMenu = paths.endsWith(URL_MAINMENU);
    const noBCrumbs = (paths.endsWith(URL_AGENCY_SELECT) || paths.endsWith(URL_APPLICATION_SELECT))
        || (!selectedApplication || !selectedAgency);

    //console.log("paths: ", paths, selectedAgency, selectedApplication);

    let displayPath = { name: "", route: "" };
    let displayTitle = "";
    !atMainMenu && containerMenu.map((topPage, index) => {
        topPage.pages.map((page) => {
            if (page.route === paths) {
                displayTitle = topPage.topTitle;
                displayPath = { name: page.breadCrumbTitle, route: page.route };
            }
        })
    });

    if (noBCrumbs || atMainMenu) {
        return (<></>)
    } else {
        return (
            <div className="bcrumbs-bar-wrapper" >
                <div className="bcrumbs-bar">
                    <Breadcrumbs aria-label="breadcrumb" separator="›"
                    sx={{ "{{" }} borderRadius: 5, lineHeight: '1rem'{{ "}}" }}
                    >
                        <Link
                            underline="hover"
                            color="inherit"
                            onClick={() => { router.push(URL_MAINMENU) {{ "}}" }}
                            sx={{ "{{" }} cursor: 'pointer'}}
                        >{displayTitle}</Link>
                        <Typography variant="h6">{displayPath.name}</Typography>
                    </Breadcrumbs>
                </div>
            </div>
        )
    }

}
