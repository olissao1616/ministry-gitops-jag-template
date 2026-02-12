'use client';

import Avatar from "@mui/material/Avatar"
import Popover from '@mui/material/Popover';
import Button from '@mui/material/Button';
import { Typography } from "@mui/material";
import { signIn, signOut, useSession } from "next-auth/react";
import { useEffect, useState } from 'react';
import { useAtom } from "jotai";
import { psSelectTabStateAtom, selectedAgencyAtom, selectedApplicationAtom } from "../store/atoms";
import { RESET } from "jotai/utils";
import { User } from "../types/data-types";
import { getInitials } from "../lib/util";
import { detectNavChange } from "./DetectNavChange";

type Props = {
    user: User | undefined,
}

export default function Card({ user }: Props) {
    const [selectedAgency, setSelectedAgency] = useAtom(selectedAgencyAtom);
    const [selectedApplication, setSelectedApplication] = useAtom(selectedApplicationAtom);
    const { data: session } = useSession()
    const [psSelectTabState, setPsSelectTabState] = useAtom(psSelectTabStateAtom);
    
    useEffect(() => {
        if (session?.error === 'RefreshAccessTokenError') {
            // delete 'selectedAgency' and 'selectedApplication' from storage
            setSelectedAgency(RESET);
            setSelectedApplication(RESET);
            // force sign in
            signIn()
        };
        //console.log("read jotai seleted agency: " + selectedAgency)
    }, [session, selectedAgency, selectedApplication])

    // Clear state if the route changes
    detectNavChange(() => setPsSelectTabState(null));
    
    //Once logged in build Avatar of user img or its initials
    const setUserImage = (user: any) => {
        var initial = getInitials(user?.name);
        var avatarContent = user?.image?.src ? <Avatar src={user?.image?.src} alt={user?.name} /> : <Avatar>{initial}</Avatar>;
        //var avatarContent = <img src="blankPersonImg?.src"/>
        return avatarContent;
    };

    //Sign-out popover mui
    const [anchorEl, setAnchorEl] = useState<HTMLButtonElement | null>(null);
    var open = Boolean(anchorEl);
    const id = open ? 'sign-out-popover' : undefined;
    const handleClick = (event: React.MouseEvent<HTMLButtonElement>) => {
        setAnchorEl(event.currentTarget);
    };

    const handleClose = () => {
        setAnchorEl(null);
        open = false;
    };

    return (
        <div className="flex-item header-info" >
            <Button aria-describedby={id} variant="contained" onClick={handleClick}
                sx={{ "{{" }} my: 0, py: 0, height: '100%', '&:hover': { bgcolor: 'primary.light' } {{ "}}" }}>
                <div className="header-profile-button">
                    <div className="header-text-container">
                        <div>
                            {user?.name}
                        </div>
                        <Typography variant="h6">
                            {selectedAgency?.agencyAssignment?.agencyName ? selectedAgency?.agencyAssignment?.agencyName + "  " : ""}
                        </Typography>
                    </div>
                    <div>
                        <div >{setUserImage(user)}</div>
                    </div>
                </div>
            </Button>

            <Popover
                id={id}
                open={open}
                anchorEl={anchorEl}
                onClose={handleClose}
                anchorOrigin={{ "{{" }}
                    vertical: 'bottom',
                    horizontal: 'right',
                {{ "}}" }}
                transformOrigin={{ "{{" }}
                    vertical: "top",
                    horizontal: "right",
                {{ "}}" }}
            >
                <Button aria-describedby="signout" variant="text" onClick={() => {
                    if (open) {
                        setSelectedAgency(RESET);
                        setSelectedApplication(RESET);
                        signOut();
                    }
                {{ "}}" }}>
                    <div className="text-sign-out">Sign Out</div>
                </Button>
            </Popover>
        </div >
    )

}
function setPsSelectTabState(arg0: null): void {
    throw new Error("Function not implemented.");
}

