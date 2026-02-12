export interface User {
    name?: string | null | undefined;
    email?: string | null | undefined;
    image?: string | null | undefined;
}

export interface type_options {
    label: string,
    text: string,
    value: string,
    desc?: string,
}