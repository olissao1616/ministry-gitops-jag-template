import { type_agency } from "@/app/protected/agency/data-types";
import { type_application } from "@/app/protected/data-types";
import { type_participantAssignment, type_psSelectTabState } from "@/app/protected/mainmenu/personnelschedule/data-types";
import { atom } from "jotai";
import { atomWithStorage } from 'jotai/utils';

/**
 * SelectedApplication, selectedAgency atoms, agencies atom
 */
export const selectedApplicationAtom = atomWithStorage<type_application | undefined>("selectedApplication", undefined);
export const selectedAgencyAtom = atomWithStorage<type_agency | undefined>("selectedAgency", undefined);
export const agenciesAtom = atom<type_agency[] | null>(null);


/**
 * Atoms used in Personnel scheduling
 */
// selected particAssignements atom
export const psSelectedParticAssignmentsAtom = atom<type_participantAssignment[] | null>(null);

// deSelected particAssignement atom
export const psDeselectedParticAssignmentAtom = atom<type_participantAssignment | null>(null);

//Personnel scheduleing select tab atom, used to maintain the selected state
export const psSelectTabStateAtom = atom<type_psSelectTabState | null>(null);


export const refreshShiftLadderStepAtom = atom<number | null>(null);