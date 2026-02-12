'use client';

import { useEffect, useState } from 'react';
import { useAtom } from "jotai";
import { selectedApplicationAtom, selectedAgencyAtom } from "../store/atoms";
import { Box, Button, IconButton, Stack } from '@mui/material';
import { useTheme } from '@mui/material/styles';
import { usePathname, useRouter } from 'next/navigation';
import DomainIcon from '@mui/icons-material/Domain';
import { URL_AGENCY_SELECT, URL_APPLICATION_SELECT, URL_MAINMENU, navMenus } from '../types/const';

export default function Nav() {
    const router = useRouter();
    const pathname = usePathname();
    const [selectedApplication, setSelectedApplication] = useAtom(selectedApplicationAtom);
    const [selectedAgency, setSelectedAgency] = useAtom(selectedAgencyAtom);
    const [mainMenuState, setMainMenuState] = useState<boolean[]>([]);

    const theme = useTheme();
    useEffect(() => {
        if (pathname.endsWith(URL_APPLICATION_SELECT) || pathname.endsWith(URL_AGENCY_SELECT)){
            setMainMenuState([false, true, true, true]);
        }
        if (pathname.indexOf(URL_MAINMENU) >= 0) {
            setMainMenuState([true, false, true, true]);
        }
    }, [pathname])

    return (
        <div className='headerNavContainer'>
            <nav className='navigation-text'>
                {selectedApplication?.description ? selectedApplication?.description + "  " : ""}
            </nav>
            <nav className='navigation-menu'>
               <Box sx={{ "{{" }} flexGrow: 0, display: { xs: 'none', md: 'flex' } {{ "}}" }}>
                <Stack alignItems="center" width="fit-content" spacing={4} direction="row">
                    <IconButton size="small"
                        disabled={selectedAgency == null}
                        sx={{ "{{" }}
                            color: theme.palette.background.default,
                            backgroundColor: mainMenuState[0] ? theme.palette.primary.main : theme.palette.primary.dark,
                          {{ "}}" }}
                        onClick={() => {
                            let currentState = [true, true, true, true];
                            currentState[0] = false;
                            setMainMenuState(currentState);
                            router.push(URL_AGENCY_SELECT); {{ "}}" }}
                    >
                        <DomainIcon />
                    </IconButton>
                    {selectedAgency != null && navMenus.map((page, index) => (
                        <Button
                            key={page.title}
                            onClick={() => {
                                let currentState = [true, true, true, true];
                                currentState[index + 1] = false;
                                setMainMenuState(
                                    currentState
                                );
                                router.push(page.route); {{ "}}" }}
                            sx={{ "{{" }} my: 2, color: theme.palette.primary.contrastText, background: mainMenuState[index + 1] ? theme.palette.primary.main : theme.palette.primary.dark {{ "}}" }}
                        >
                            {page.title}
                        </Button>
                    ))}
                </Stack>
                </Box>
            </nav>
        </div>
    )
}